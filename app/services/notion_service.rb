require 'httparty'
require 'securerandom'

class NotionService
  include HTTParty
  base_uri 'https://api.notion.com/v1'
  format :json

  def initialize(api_key = nil, db_id = nil)
    @api_key = api_key || ENV['NOTION_API_KEY']
    @database_id = db_id || ENV['NOTION_DATABASE_ID']

    # Set mock_mode to true if no API key or database ID is provided
    @mock_mode = @api_key.nil? || @api_key.empty? || @api_key == 'your_notion_api_key_here' ||
                 @database_id.nil? || @database_id.empty? || @database_id == 'your_notion_database_id_here'

    # Format database ID if needed (add hyphens if they're missing)
    if !@mock_mode && @database_id.present?
      @database_id = format_database_id(@database_id)
    end

    # Only set headers if we're not in mock mode
    unless @mock_mode
      self.class.headers({
        'Authorization' => "Bearer #{@api_key}",
        'Notion-Version' => '2022-06-28',
        'Content-Type' => 'application/json'
      })
    end
  end

  def export_task(task)
    if @mock_mode
      # Return mock successful response with fake page ID
      mock_page_id = "mock-page-id-#{SecureRandom.hex(10)}"
      Rails.logger.info "MOCK MODE: Simulating successful export to Notion with ID: #{mock_page_id}"

      # Store the mock page ID in the task for consistency
      task.update(notion_page_id: mock_page_id) if task.respond_to?(:notion_page_id)

      return { success: true, page_id: mock_page_id }
    end

    begin
      # Test database access first
      test_response = test_database_access
      if !test_response[:success]
        return test_response
      end

      # First check if we have a stored Notion page ID
      task_page_id = nil

      if task.notion_page_id.present?
        # Verify this page still exists in Notion
        if page_exists?(task.notion_page_id)
          task_page_id = task.notion_page_id
          update_task_page(task, task_page_id)
          Rails.logger.info "Updated existing Notion page with ID: #{task_page_id}"
        else
          # Page was deleted in Notion, we'll create a new one
          Rails.logger.info "Stored Notion page ID no longer exists, creating new page"
          task.update(notion_page_id: nil)
        end
      end

      # If no valid notion_page_id was found, try finding by title
      if task_page_id.nil?
        existing_task_id = find_task_by_title(task.title)

        if existing_task_id
          task_page_id = existing_task_id
          update_task_page(task, task_page_id)
          # Save the found ID for future use
          task.update(notion_page_id: task_page_id)
          Rails.logger.info "Found and updated existing Notion page by title with ID: #{task_page_id}"
        else
          # Create new task page
          Rails.logger.info "Creating new Notion page for task: #{task.title}"
          task_page_id = create_task_page(task)
          # Save the new ID
          task.update(notion_page_id: task_page_id) if task_page_id
        end
      end

      # Process subtasks if we have a valid task_page_id
      if task_page_id
        # Process each subtask
        task.subtasks.each do |subtask|
          process_subtask(subtask, task_page_id)
        end

        return { success: true, page_id: task_page_id }
      else
        return { success: false, error: "Failed to process task in Notion" }
      end
    rescue StandardError => e
      Rails.logger.error "Notion API error: #{e.message}"
      return { success: false, error: e.message }
    end
  end

  private

  # Process a single subtask - create or update as needed
  def process_subtask(subtask, parent_task_id)
    subtask_page_id = nil

    # First check if we have a stored Notion page ID for this subtask
    if subtask.notion_page_id.present?
      # Verify this page still exists in Notion
      if page_exists?(subtask.notion_page_id)
        subtask_page_id = subtask.notion_page_id
        update_subtask_page(subtask, subtask_page_id, parent_task_id)
        Rails.logger.info "Updated existing Notion subtask with ID: #{subtask_page_id}"
        return true
      else
        # Page was deleted in Notion, we'll create a new one
        Rails.logger.info "Stored Notion subtask ID no longer exists, will create new"
        subtask.update(notion_page_id: nil)
      end
    end

    # If we don't have a valid notion_page_id, try to find by title + parent relation
    if subtask_page_id.nil?
      existing_subtasks = get_subtasks_for_parent(parent_task_id)
      existing_subtask = existing_subtasks.find { |es| es[:title].downcase == subtask.title.downcase }

      if existing_subtask
        subtask_page_id = existing_subtask[:id]
        update_subtask_page(subtask, subtask_page_id, parent_task_id)
        # Save the found ID
        subtask.update(notion_page_id: subtask_page_id)
        Rails.logger.info "Found and updated existing subtask by title with ID: #{subtask_page_id}"
      else
        # Create new subtask
        Rails.logger.info "Creating new Notion page for subtask: #{subtask.title}"
        new_subtask_id = create_subtask_page(subtask, parent_task_id)
        # Save the new ID
        subtask.update(notion_page_id: new_subtask_id) if new_subtask_id
      end
    end

    return subtask_page_id.present?
  end

  # Check if a Notion page still exists
  def page_exists?(page_id)
    begin
      response = self.class.get("/pages/#{page_id}")
      return response.success?
    rescue StandardError
      return false
    end
  end

  def test_database_access
    begin
      response = self.class.get("/databases/#{@database_id}")

      if response.success?
        return { success: true }
      else
        error_msg = case response.code
        when 404
          "Database not found. Please check that:\n" +
          "1. Your database ID is correct: #{@database_id}\n" +
          "2. You've shared the database with your integration\n" +
          "3. Your integration token has access to the database"
        when 401
          "Authentication failed. Please check your Notion API key."
        else
          "Notion API error: #{response.code} - #{response.body}"
        end

        Rails.logger.error error_msg
        return { success: false, error: error_msg }
      end
    rescue StandardError => e
      return { success: false, error: "Error accessing Notion database: #{e.message}" }
    end
  end

  def format_database_id(id)
    # If the ID already has hyphens, return it as is
    return id if id.include?('-')

    # Format as UUID with hyphens: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    if id.length == 32
      "#{id[0..7]}-#{id[8..11]}-#{id[12..15]}-#{id[16..19]}-#{id[20..31]}"
    else
      # If it's not in the expected format, return as is
      id
    end
  end

  # Find a task in Notion by its title
  def find_task_by_title(title)
    query_params = {
      filter: {
        property: "Name",
        title: {
          equals: title
        }
      }
    }

    response = self.class.post(
      "/databases/#{@database_id}/query",
      body: query_params.to_json
    )

    if response.success? && response['results'].present?
      return response['results'][0]['id']
    end

    nil
  end

  # Get all subtasks for a parent task
  def get_subtasks_for_parent(parent_task_id)
    query_params = {
      filter: {
        property: "Parent Task",
        relation: {
          contains: parent_task_id
        }
      }
    }

    response = self.class.post(
      "/databases/#{@database_id}/query",
      body: query_params.to_json
    )

    subtasks = []

    if response.success? && response['results'].present?
      response['results'].each do |result|
        title = result.dig('properties', 'Name', 'title')&.first&.dig('text', 'content')
        subtasks << { id: result['id'], title: title } if title
      end
    end

    subtasks
  end

  def create_task_page(task)
    response = self.class.post(
      '/pages',
      body: {
        parent: { database_id: @database_id },
        properties: build_task_properties(task)
      }.to_json
    )

    if response.success?
      response['id']
    else
      Rails.logger.error "Failed to create Notion page: #{response.code} #{response.body}"
      nil
    end
  end

  def update_task_page(task, page_id)
    response = self.class.patch(
      "/pages/#{page_id}",
      body: {
        properties: build_task_properties(task)
      }.to_json
    )

    unless response.success?
      Rails.logger.error "Failed to update Notion page: #{response.code} #{response.body}"
    end

    response.success?
  end

  def build_task_properties(task)
    {
      "Name": {
        title: [
          {
            text: {
              content: task.title
            }
          }
        ]
      },
      "Description": {
        rich_text: [
          {
            text: {
              content: task.description || ""
            }
          }
        ]
      },
      "Status": {
        select: {
          name: task.status.titleize
        }
      },
      "Priority": {
        select: {
          name: task.priority.titleize
        }
      }
    }
  end

  def create_subtask_page(subtask, parent_task_id)
    response = self.class.post(
      '/pages',
      body: {
        parent: { database_id: @database_id },
        properties: build_subtask_properties(subtask, parent_task_id)
      }.to_json
    )

    if response.success?
      response['id']
    else
      Rails.logger.error "Failed to create Notion subtask: #{response.code} #{response.body}"
      nil
    end
  end

  def update_subtask_page(subtask, page_id, parent_task_id = nil)
    # If parent_task_id is provided, include it in the update
    properties = build_subtask_properties(subtask, parent_task_id)

    response = self.class.patch(
      "/pages/#{page_id}",
      body: {
        properties: properties
      }.to_json
    )

    unless response.success?
      Rails.logger.error "Failed to update Notion subtask: #{response.code} #{response.body}"
    end

    response.success?
  end

  def build_subtask_properties(subtask, parent_task_id)
    properties = {
      "Name": {
        title: [
          {
            text: {
              content: subtask.title
            }
          }
        ]
      },
      "Description": {
        rich_text: [
          {
            text: {
              content: subtask.description || ""
            }
          }
        ]
      },
      "Status": {
        select: {
          name: subtask.status.titleize
        }
      }
    }

    # Only include parent relation if parent_task_id is provided
    if parent_task_id.present?
      properties["Parent Task"] = {
        relation: [
          {
            id: parent_task_id
          }
        ]
      }
    end

    properties
  end
end

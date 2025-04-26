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
      # Return mock successful response
      Rails.logger.info "MOCK MODE: Simulating successful export to Notion"
      return { success: true, page_id: "mock-page-id-#{SecureRandom.hex(10)}" }
    end

    begin
      # Test database access first
      test_response = test_database_access

      if !test_response[:success]
        return test_response
      end

      # Create parent task page in Notion
      task_page_id = create_task_page(task)

      # Create subtask pages if parent task was created successfully
      if task_page_id
        task.subtasks.each do |subtask|
          create_subtask_page(subtask, task_page_id)
        end

        return { success: true, page_id: task_page_id }
      else
        return { success: false, error: "Failed to create task in Notion" }
      end
    rescue StandardError => e
      Rails.logger.error "Notion API error: #{e.message}"
      return { success: false, error: e.message }
    end
  end

  private

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

  def create_task_page(task)
    response = self.class.post(
      '/pages',
      body: {
        parent: { database_id: @database_id },
        properties: {
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
          },
          "Parent Task": {
            relation: []
          }
        }
      }.to_json
    )

    if response.success?
      response['id']
    else
      Rails.logger.error "Failed to create Notion page: #{response.code} #{response.body}"
      nil
    end
  end

  def create_subtask_page(subtask, parent_task_id)
    response = self.class.post(
      '/pages',
      body: {
        parent: { database_id: @database_id },
        properties: {
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
          },
          "Parent Task": {
            relation: [
              {
                id: parent_task_id
              }
            ]
          }
        }
      }.to_json
    )

    unless response.success?
      Rails.logger.error "Failed to create Notion subtask: #{response.code} #{response.body}"
    end

    response.success?
  end
end

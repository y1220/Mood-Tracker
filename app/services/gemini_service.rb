require 'httparty'

class GeminiService
  include HTTParty
  BASE_URL = 'https://generativelanguage.googleapis.com/v1'

  def initialize(api_key = nil)
    @api_key = api_key || ENV['GEMINI_API_KEY']
    # Set mock_mode to true if no API key is provided
    @mock_mode = @api_key.nil? || @api_key.empty? || @api_key == 'your_gemini_api_key_here'
  end

  def generate_subtasks(task)
    if @mock_mode
      # Return mock data for testing without an API key
      return generate_mock_subtasks(task)
    end

    model = 'models/gemini-1.5-pro'
    endpoint = "#{BASE_URL}/#{model}:generateContent"

    prompt = build_subtask_prompt(task)
    response = self.class.post(
      endpoint,
      query: { key: @api_key },
      headers: { 'Content-Type' => 'application/json' },
      body: {
        contents: [
          {
            role: 'user',
            parts: [{ text: prompt }]
          }
        ],
        generationConfig: {
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048
        }
      }.to_json
    )

    if response.success?
      parse_subtasks_from_response(response)
    else
      Rails.logger.error "Gemini API error: #{response.code} #{response.body}"
      []
    end
  end

  private

  def build_subtask_prompt(task)
    <<~PROMPT
      You are a task management assistant. Please help break down the following task into 5-7 logical subtasks.
      For each subtask, provide a clear title and a brief description.

      Main task: #{task.title}
      Description: #{task.description}

      Please format your response as a JSON array of objects with 'title' and 'description' keys for each subtask.
      Example format:
      [
        {"title": "First subtask", "description": "Description of first subtask"},
        {"title": "Second subtask", "description": "Description of second subtask"}
      ]

      Only respond with the JSON array, no additional text or explanations.
    PROMPT
  end

  def generate_mock_subtasks(task)
    # Generate different mock subtasks based on the task title/description
    case task.title.downcase
    when /meeting|discuss|talk/
      [
        { 'title' => 'Create meeting agenda', 'description' => 'Outline the key topics to be discussed.' },
        { 'title' => 'Send calendar invites', 'description' => 'Schedule the meeting and invite all participants.' },
        { 'title' => 'Prepare presentation', 'description' => 'Create slides or materials needed for the meeting.' },
        { 'title' => 'Book meeting room', 'description' => 'Reserve an appropriate space for the meeting.' },
        { 'title' => 'Follow up with minutes', 'description' => 'Document decisions and action items after the meeting.' }
      ]
    when /write|document|report/
      [
        { 'title' => 'Research the topic', 'description' => 'Gather information and data needed for the document.' },
        { 'title' => 'Create outline', 'description' => 'Structure the document with main sections and points.' },
        { 'title' => 'Write first draft', 'description' => 'Complete an initial version of the document.' },
        { 'title' => 'Review and edit', 'description' => 'Check for errors and improve clarity.' },
        { 'title' => 'Format document', 'description' => 'Add proper formatting, citations, and references.' },
        { 'title' => 'Seek feedback', 'description' => 'Get input from colleagues or stakeholders.' },
        { 'title' => 'Finalize and submit', 'description' => 'Make final revisions and submit the document.' }
      ]
    else
      # Default subtasks for any other type of task
      [
        { 'title' => 'Define requirements', 'description' => 'Clearly specify what needs to be accomplished.' },
        { 'title' => 'Research options', 'description' => 'Explore potential approaches and solutions.' },
        { 'title' => 'Create action plan', 'description' => 'Outline the steps needed to complete the task.' },
        { 'title' => 'Execute the plan', 'description' => 'Carry out the necessary actions.' },
        { 'title' => 'Test and validate', 'description' => 'Ensure the results meet the requirements.' },
        { 'title' => 'Review and finalize', 'description' => 'Make any necessary adjustments and complete the task.' }
      ]
    end
  end

  def parse_subtasks_from_response(response)
    begin
      # Extract text content from Gemini response
      text = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
      return [] unless text

      # Parse JSON from the response
      json_start = text.index('[')
      json_end = text.rindex(']')

      if json_start && json_end
        json_str = text[json_start..json_end]
        JSON.parse(json_str)
      else
        Rails.logger.error "Failed to extract JSON from Gemini response: #{text}"
        []
      end
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing error: #{e.message}"
      []
    rescue StandardError => e
      Rails.logger.error "Error parsing Gemini response: #{e.message}"
      []
    end
  end
end

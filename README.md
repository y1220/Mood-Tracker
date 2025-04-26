# Mood Tracker

A comprehensive web application for tracking your moods and managing tasks with AI assistance. This Rails application helps users monitor their emotional well-being and efficiently organize tasks with smart features like AI-generated subtasks and Notion integration.

## Features

### Mood Tracking
- Track daily mood patterns
- Visualize emotional trends over time
- Identify factors affecting your emotional well-being

### Task Management with AI Integration
- Create and manage tasks with priorities and statuses
- Generate subtasks automatically using Google's Gemini AI
- Select and save AI-suggested subtasks
- Export tasks and subtasks to Notion for further organization

## Technology Stack

- **Framework**: Ruby on Rails 8.0
- **Database**: SQLite (development), configurable for production
- **Frontend**: HTML/ERB, CSS, JavaScript with Hotwired
- **CSS Framework**: Bootstrap
- **API Integrations**:
  - Google Gemini API (for AI-generated subtasks)
  - Notion API (for task export)

## Prerequisites

- Ruby 3.2.0 or higher
- Rails 8.0
- Node.js and Yarn
- API Keys for Gemini and Notion (for full functionality)

## Installation

1. Clone the repository
```bash
git clone https://github.com/y1220/Mood-Tracker.git
cd mood_tracker
```

2. Install dependencies
```bash
bundle install
```

3. Set up the database
```bash
bin/rails db:create db:migrate
```

4. Configure environment variables
Create a `.env` file in the root directory with the following variables:
```
GEMINI_API_KEY=your_gemini_api_key_here
NOTION_API_KEY=your_notion_api_key_here
NOTION_DATABASE_ID=your_notion_database_id_here
```

5. Start the development server
```bash
bin/dev
```

6. Visit `http://localhost:3000` in your browser

## Setting Up API Integrations

### Google Gemini API
1. Obtain an API key from [Google AI Studio](https://makersuite.google.com/)
2. Add the key to your `.env` file

### Notion API
1. Create an integration at [Notion Developers](https://www.notion.so/my-integrations)
2. Create a database in Notion with the following properties:
   - Name (title)
   - Description (text)
   - Status (select)
   - Priority (select)
   - Parent Task (relation, for subtasks)
3. Share the database with your integration
4. Add your API key and database ID to the `.env` file

## Docker Support

The application includes Docker support for easy deployment:

```bash
docker build -t mood-tracker .
docker run -p 3000:3000 mood-tracker
```

## Testing

Run the test suite with:

```bash
bin/rails test
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

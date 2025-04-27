module ApplicationHelper
  # Generate a URL to a Notion page
  def notion_page_url(page_id)
    return nil unless page_id.present?

    # Notion page URLs are in the format: https://notion.so/[workspace]/[page-id]
    # The workspace part is optional, so we'll use the simple format
    "https://notion.so/#{page_id.gsub('-', '')}"
  end
end

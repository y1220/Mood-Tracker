class AddNotionPageIdToTasksAndSubtasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :notion_page_id, :string
    add_column :subtasks, :notion_page_id, :string

    add_index :tasks, :notion_page_id
    add_index :subtasks, :notion_page_id
  end
end

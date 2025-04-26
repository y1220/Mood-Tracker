class CreateSubtasks < ActiveRecord::Migration[8.0]
  def change
    create_table :subtasks do |t|
      t.string :title
      t.text :description
      t.integer :task_id
      t.string :status

      t.timestamps
    end
  end
end

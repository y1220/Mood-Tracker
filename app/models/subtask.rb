class Subtask < ApplicationRecord
  belongs_to :task

  validates :title, presence: true

  # Status options
  enum :status, {
    pending: 'pending',
    in_progress: 'in_progress',
    completed: 'completed'
  }, default: 'pending'
end

class Task < ApplicationRecord
  has_many :subtasks, dependent: :destroy

  validates :title, presence: true

  # Status options
  enum :status, {
    pending: "pending",
    in_progress: "in_progress",
    completed: "completed"
  }, default: "pending"

  # Priority options
  enum :priority, {
    low: "low",
    medium: "medium",
    high: "high"
  }, default: "medium"
end

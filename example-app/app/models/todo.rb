class Todo < ApplicationRecord
  validates :title, presence: true
  validates :title, length: { maximum: 255 }
  validates :completed, inclusion: { in: [true, false] }

  scope :completed,   -> { where(completed: true) }
  scope :incomplete,  -> { where(completed: false) }
end

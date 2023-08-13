class Task < ApplicationRecord
  scope :completed, -> { where.not(completed_at: nil) }
  scope :in_progress, -> { where(completed_at: nil) }
  
  belongs_to :assignee, class_name: "Account", foreign_key: "assignee_id", primary_key: "public_id"
end

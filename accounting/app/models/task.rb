# frozen_string_literal: true

class Task < ApplicationRecord
  scope :completed, -> { where.not(completed_at: nil) }
  scope :in_progress, -> { where(completed_at: nil) }
  
  has_many :audit_logs, primary_key: "public_id"
  belongs_to :assignee, class_name: "Account", foreign_key: "assignee_id", primary_key: "public_id"
end

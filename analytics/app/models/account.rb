# frozen_string_literal: true

class Account < ApplicationRecord
  scope :workers, -> { where(role: "worker") }

  has_many :tasks, foreign_key: "assignee_id", primary_key: "public_id"
  has_many :audit_logs, primary_key: "public_id"
end

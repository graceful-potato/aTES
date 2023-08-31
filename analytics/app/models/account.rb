# frozen_string_literal: true

class Account < ApplicationRecord
  scope :workers, -> { where(role: "worker") }

  has_many :tasks, foreign_key: "assignee_id", primary_key: "public_id"
  has_many :billing_cycles, primary_key: "public_id"
  has_many :transactions, primary_key: "public_id"
  has_one :current_billing_cycle, -> { where(":now >= starts_at and :now <= ends_at", now: DateTime.current)
                                      .where(status: "open") },
                                  class_name: "BillingCycle",
                                  primary_key: "public_id"
end

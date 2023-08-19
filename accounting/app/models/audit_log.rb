# frozen_string_literal: true

class AuditLog < ApplicationRecord
  belongs_to :account, primary_key: "public_id", optional: true
  belongs_to :task, primary_key: "public_id", optional: true
end

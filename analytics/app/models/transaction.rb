# frozen_string_literal: true

class Transaction < ApplicationRecord
  enum kind: [ :deposit, :withdrawal, :payout ]
  enum direction: [ :credit, :debit ]


  belongs_to :billing_cycle, primary_key: "public_id"
  belongs_to :account, primary_key: "public_id"
  belongs_to :task, primary_key: "public_id", optional: true
end

# frozen_string_literal: true

class BillingCycle < ApplicationRecord
  enum status: [ :open, :closed ]

  belongs_to :account, primary_key: "public_id"
  has_many :transactions, primary_key: "public_id"

  def balance
    transactions.sum("transactions.credit - transactions.debit")
  end
end

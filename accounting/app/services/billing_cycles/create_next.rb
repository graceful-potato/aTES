# frozen_string_literal: true

class BillingCycles::CreateNext < ApplicationService
  def call
    start_time = DateTime.tomorrow.beginning_of_day
    end_time = DateTime.tomorrow.end_of_day

    Account.workers.find_each do |account|
      BillingCycles::FetchOrCreate.call(account, start_time, end_time)
    end
  end
end

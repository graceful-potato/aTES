# frozen_string_literal: true

class Api::V1::DashboardsController < ApplicationController
  before_action :authenticate_account!

  def show
    if current_account.role.in?(["admin", "bookkeeper"])
      @total = Transaction.where("created_at >= ? AND created_at <= ?",
                                 DateTime.current.beginning_of_day,
                                 DateTime.current.end_of_day)
                          .where(kind: ["withdrawal", "deposit"])
                          .sum("transactions.credit + transactions.debit")

      render "dashboard"
    elsif current_account.role == "worker"
      @transactions = current_account.transactions.includes(:task).order(created_at: :desc)
      render "worker_dashboard"
    end
  end
end

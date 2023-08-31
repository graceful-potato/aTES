# frozen_string_literal: true

class Api::V1::DashboardsController < ApplicationController
  before_action :authenticate_account!

  def show
    if current_account.role != "admin"
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    @negative_balances_count = Account.where("balance < 0").count
    @total = Transaction.where("created_at >= ? AND created_at <= ?",
                               DateTime.current.beginning_of_day,
                               DateTime.current.end_of_day)
                        .where(kind: ["withdrawal", "deposit"])
                        .sum("transactions.credit + transactions.debit")
    
    @from = from
    @to = to
    @most_expensive_task = Transaction.where("created_at >= ? AND created_at <= ?", from, to)
                                      .where(kind: "deposit")
                                      .order(credit: :desc)
                                      .limit(1)
                                      .first
                                      .task
  end

  private

  def from
    @_from ||= begin
      if params[:from]
        DateTime.parse(params[:from]).beginning_of_day
      else
        Time.zone.today.beginning_of_day
      end
    rescue Date::Error
      Time.zone.today.beginning_of_day
    end
  end

  def to
    @_to ||= begin
      if params[:to]
        DateTime.parse(params[:to]).end_of_day
      else
        Time.zone.today.end_of_day
      end
    rescue Date::Error
      Time.zone.today.end_of_day
    end
  end
end

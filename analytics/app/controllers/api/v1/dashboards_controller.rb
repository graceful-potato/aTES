# frozen_string_literal: true

class Api::V1::DashboardsController < ApplicationController
  before_action :authenticate_account!

  def show
    if current_account.role != "admin"
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    @negative_balances_count = Account.where("balance < 0").count
    @today_withdrawals = AuditLog.where("created_at >= ? AND created_at <= ?",
                                        Time.zone.today.beginning_of_day,
                                        Time.zone.today.end_of_day)
                                  .where(event_type: "withdrawal")
                                  .sum(:amount)
    @today_deposits = AuditLog.where("created_at >= ? AND created_at <= ?",
                                      Time.zone.today.beginning_of_day,
                                      Time.zone.today.end_of_day)
                              .where(event_type: "deposit")
                              .sum(:amount)
    
    @from = from
    @to = to
    @most_expensive_task = AuditLog.where("created_at >= ? AND created_at <= ?", from, to)
                        .where(event_type: "deposit")
                        .order(amount: :desc)
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

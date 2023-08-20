# frozen_string_literal: true

class Api::V1::DashboardsController < ApplicationController
  before_action :authenticate_account!

  def show
    if current_account.role.in?(["admin", "bookkeeper"])
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
      render "dashboard"
    elsif current_account.role == "worker"
      @logs = current_account.audit_logs.includes(:task).order(created_at: :desc)
      render "worker_dashboard"
    end
  end
end

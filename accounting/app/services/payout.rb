# frozen_string_literal: true

class Payout < ApplicationService
  def call
    Account.workers.each do |worker|
      balance = worker.balance
      next if balance <= 0

      ActiveRecord::Base.transaction do
        worker.update(balance: 0)

        # TODO: Send email?

        log = AuditLog.create!(account: worker, amount: balance, event_type: "payout").reload

        event = {
          event_id: SecureRandom.uuid,
          event_version: 1,
          event_time: DateTime.current,
          producer: "accounting",
          event_name: "AuditLogCreated",
          data: {
            public_id: log.public_id,
            account_id: log.account_id,
            task_id: nil,
            amount: log.amount,
            event_type: log.event_type,
            created_at: log.created_at
          }
        }
        
        encoded_event = AVRO.encode(event, schema_name: "auditlogs_stream.created")
        ProduceEventJob.perform_async(topic: "auditlogs-stream", payload: encoded_event)
      end
    end
  end
end

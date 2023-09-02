# frozen_string_literal: true

class Payout < ApplicationService
  def call
    Account.workers.find_each do |worker|
      prev_billing_cycle = worker.billing_cycles
                                 .where(":yesterday >= starts_at and :yesterday <= ends_at",
                                        yesterday: DateTime.current - 1.day).first
      curr_billing_cycle = worker.current_billing_cycle
      balance = worker.balance - curr_billing_cycle.balance

      if balance <= 0
        BillingCycles::Close(prev_billing_cycle) if prev_billing_cycle
        next
      end

      ActiveRecord::Base.transaction do
        worker.update!(balance: 0)
        
        transaction = Transaction.create!(
          billing_cycle: prev_billing_cycle,
          account: worker,
          description: "Payout",
          debit: balance,
          direction: "debit",
          kind: "payout"
        ).reload

        BillingCycles::Close(prev_billing_cycle)

        event = {
          event_id: SecureRandom.uuid,
          event_version: 1,
          event_time: DateTime.current,
          producer: "accounting",
          event_name: "Paidout",
          data: {
            public_id: transaction.public_id,
            billing_cycle_id: transaction.billing_cycle_id
            account_id: transaction.account_id,
            description: transaction.description,
            credit: transaction.credit,
            debit: transaction.debit,
            direction: transaction.direction,
            kind: transaction.kind,
            created_at: transaction.created_at
          }
        }
        encoded_event = Base64.encode64(AVRO.encode(event, subject: "transactions.paidout", version: 1))
        ProduceEventJob.perform_async("transactions", encoded_event)

        # TODO: Send email?
      end
    end
  end
end

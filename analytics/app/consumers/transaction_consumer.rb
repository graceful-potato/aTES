# frozen_string_literal: true

class TransactionConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = AVRO.decode(message.raw_payload)

      puts "-" * 80
      puts payload
      puts "-" * 80

      case payload["event_name"]
      when "Paidout"
        ActiveRecord::Base.transaction do
          account = Account.find_or_create_by!(public_id: payload["data"]["account_id"])

          billing_cycle = BillingCycle.find_or_create_by!(
            public_id: payload["data"]["billing_cycle_id"],
            account_id: payload["data"]["account_id"]
          )

          transaction = Transaction.create!(
            public_id: payload["data"]["public_id"],
            billing_cycle: billing_cycle,
            account: account,
            description: payload["data"]["description"],
            debit: payload["data"]["debit"],
            credit: payload["data"]["credit"],
            direction: payload["data"]["direction"],
            kind: payload["data"]["kind"],
            created_at: payload["data"]["created_at"],
          )

          account.update!(balance: 0)
        end
      when "Withdrew"
        ActiveRecord::Base.transaction do
          account = Account.find_or_create_by!(public_id: payload["data"]["account_id"])

          task = Task.find_or_create_by!(public_id: payload["data"]["task_id"], assignee: account)

          billing_cycle = BillingCycle.find_or_create_by!(
            public_id: payload["data"]["billing_cycle_id"],
            account_id: payload["data"]["account_id"]
          )

          transaction = Transaction.create!(
            public_id: payload["data"]["public_id"],
            billing_cycle: billing_cycle,
            account: account,
            task: task,
            description: payload["data"]["description"],
            debit: payload["data"]["debit"],
            credit: payload["data"]["credit"],
            direction: payload["data"]["direction"],
            kind: payload["data"]["kind"],
            created_at: payload["data"]["created_at"],
          )

          account.update!(balance: account.balance - transaction.debit)
        end
      when "Deposited"
        account = Account.find_or_create_by(public_id: payload["data"]["account_id"])

        task = Task.find_or_create_by!(public_id: payload["data"]["task_id"])

        billing_cycle = BillingCycle.find_or_create_by!(
          public_id: payload["data"]["billing_cycle_id"],
          account_id: payload["data"]["account_id"]
        )

        transaction = Transaction.create!(
          public_id: payload["data"]["public_id"],
          billing_cycle: billing_cycle,
          account: account,
          task: task,
          description: payload["data"]["description"],
          debit: payload["data"]["debit"],
          credit: payload["data"]["credit"],
          direction: payload["data"]["direction"],
          kind: payload["data"]["kind"],
          created_at: payload["data"]["created_at"],
        )

        account.update!(balance: account.balance + transaction.credit)
      end
    rescue StandardError => e
      # TODO: Notify developers about exception with bugsnag/sentry
      FailedEvent.create(topic: message.topic,
                         event_id: payload["event_id"],
                         event_version: payload["event_version"],
                         event_time: payload["event_time"],
                         producer: payload["producer"],
                         event_name: payload["event_name"],
                         error_message: e.full_message,
                         raw: payload)
    end
  end

  # Run anything upon partition being revoked
  # def revoked
  # end

  # Define here any teardown things you want when Karafka server stops
  # def shutdown
  # end
end

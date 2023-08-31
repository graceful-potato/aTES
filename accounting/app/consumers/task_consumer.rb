# frozen_string_literal: true

class TaskConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = AVRO.decode(message.raw_payload)

      puts "-" * 80
      puts payload
      puts "-" * 80

      case payload["event_name"]
      when "TaskAdded"
        ActiveRecord::Base.transaction do
          # Есть вероятность, что новая ивент добавленной таски придет раньше ивента
          # создания пользователя, на которого она назначена. Поэтому можем создать
          # заглушку для аккаунта, в которую потом попадут реальные данные пользователя.
          assignee = Account.find_or_create_by(public_id: payload["data"]["assignee_id"])
          task = Task.find_or_initialize_by(public_id: payload["data"]["public_id"]).tap do |t|
            t.title = t.title || payload["data"]["title"]
            t.jira_id = t.jira_id || payload["data"]["jira_id"]
            t.description = t.description || payload["data"]["description"]
            t.completed_at = t.completed_at || payload["data"]["completed_at"]
            t.assignee = assignee
            t.fee = t.fee || payload["data"]["fee"]
            t.reward = t.reward || payload["data"]["reward"]
            t.created_at = t.created_at || payload["data"]["created_at"]
            t.save!
          end

          assignee.update(balance: assignee.balance - task.fee)

          billing_cycle = BillingCycles::FetchOrCreate.call(
            assignee,
            payload["event_time"].beginning_of_day,
            payload["event_time"].end_of_day
          )

          if billing_cycle.status == "closed"
            billing_cycle = BillingCycles::FetchOrCreate.call(
              assignee,
              DateTime.current.beginning_of_day,
              DateTime.current.end_of_day,
            )
          end

          transaction = Transaction.create!(
            billing_cycle: billing_cycle,
            account: assignee,
            task: task,
            description: "Task assign fee",
            debit: task.fee,
            direction: "debit",
            kind: "withdrawal"
          ).reload

          event = {
            event_id: SecureRandom.uuid,
            event_version: 1,
            event_time: DateTime.current,
            producer: "accounting",
            event_name: "Withdrew",
            data: {
              public_id: transaction.public_id,
              billing_cycle_id: transaction.billing_cycle_id,
              account_id: transaction.account_id,
              task_id: transaction.task_id,
              description: transaction.description,
              credit: transaction.credit,
              debit: transaction.debit,
              direction: transaction.direction,
              kind: transaction.kind,
              created_at: transaction.created_at
            }
          }

          encoded_event = Base64.encode64(AVRO.encode(event, schema_name: "transactions.withdrew"))
          ProduceEventJob.perform_async("transactions", encoded_event)
        end
      when "TaskCompleted"
        ActiveRecord::Base.transaction do
          # При обработке этого ивента так же учитываем, что на момент получения у нас
          # может не быть ни таски ни аккаунта
          assignee = Account.find_or_create_by(public_id: payload["data"]["assignee_id"])
          task = Task.find_or_create_by(public_id: payload["data"]["public_id"]) do |t|
            t.reward = payload["data"]["reward"]
            t.completed_at = payload["data"]["completed_at"]
            t.assignee = assignee
          end

          assignee.update(balance: assignee.balance + task.reward)

          billing_cycle = BillingCycles::FetchOrCreate.call(
            assignee,
            payload["event_time"].beginning_of_day,
            payload["event_time"].end_of_day
          )

          if billing_cycle.status == "closed"
            billing_cycle = BillingCycles::FetchOrCreate.call(
              assignee,
              DateTime.current.beginning_of_day,
              DateTime.current.end_of_day,
            )
          end

          transaction = Transaction.create!(
            billing_cycle: billing_cycle,
            account: assignee,
            task: task,
            description: "Task reward",
            credit: task.reward,
            direction: "credit",
            kind: "deposit"
          ).reload

          event = {
            event_id: SecureRandom.uuid,
            event_version: 1,
            event_time: DateTime.current,
            producer: "accounting",
            event_name: "Deposited",
            data: {
              public_id: transaction.public_id,
              billing_cycle_id: transaction.billing_cycle_id,
              account_id: transaction.account_id,
              task_id: transaction.task_id,
              description: transaction.description,
              credit: transaction.credit,
              debit: transaction.debit,
              direction: transaction.direction,
              kind: transaction.kind,
              created_at: transaction.created_at
            }
          }
          encoded_event = Base64.encode64(AVRO.encode(event, schema_name: "transactions.deposited"))
          ProduceEventJob.perform_async("transactions", encoded_event)
        end
      when "TasksShuffled"
        # Тут то же самое. Обрабатывает так, как будто у нас может не быть ни таски
        # ни аккаунта
        ActiveRecord::Base.transaction do
          payload["data"].each do |task_hash|
            assignee = Account.find_or_create_by(public_id: task_hash["assignee_id"])

            task = Task.find_or_create_by(public_id: task_hash["public_id"]) do |t|
              t.fee = task_hash["fee"]
            end

            task.update(assignee: assignee)
            assignee.update(balance: assignee.balance - task.fee)

            billing_cycle = BillingCycles::FetchOrCreate.call(
              assignee,
              payload["event_time"].beginning_of_day,
              payload["event_time"].end_of_day
            )

            if billing_cycle.status == "closed"
              billing_cycle = BillingCycles::FetchOrCreate.call(
                assignee,
                DateTime.current.beginning_of_day,
                DateTime.current.end_of_day,
              )
            end

            transaction = Transaction.create!(
              billing_cycle: billing_cycle,
              account: assignee,
              task: task,
              description: "Task assign fee",
              debit: task.fee,
              direction: "debit",
              kind: "withdrawal"
            ).reload
  
            event = {
              event_id: SecureRandom.uuid,
              event_version: 1,
              event_time: DateTime.current,
              producer: "accounting",
              event_name: "Withdrew",
              data: {
                public_id: transaction.public_id,
                billing_cycle_id: transaction.billing_cycle_id,
                account_id: transaction.account_id,
                task_id: transaction.task_id,
                description: transaction.description,
                credit: transaction.credit,
                debit: transaction.debit,
                direction: transaction.direction,
                kind: transaction.kind,
                created_at: transaction.created_at
              }
            }
            encoded_event = Base64.encode64(AVRO.encode(event, schema_name: "transactions.withdrew"))
            ProduceEventJob.perform_async("transactions", encoded_event)
          end
        end
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

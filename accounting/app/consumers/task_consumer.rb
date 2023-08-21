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
            t.save
          end

          assignee.update(balance: assignee.balance - task.fee)

          # --------------------------------------------------------------------
          # Balance update event

          event = {
            event_id: SecureRandom.uuid,
            event_version: 1,
            event_time: DateTime.current,
            producer: "accounting",
            event_name: "AccountBalanceUpdated",
            data: {
              public_id: assignee.public_id,
              balance: assignee.balance
            }
          }

          encoded_event = AVRO.encode(event, schema_name: "accounts_stream.balance_updated")
          Karafka.producer.produce_sync(topic: "accounts-stream", payload: encoded_event)
          # --------------------------------------------------------------------


          # --------------------------------------------------------------------
          # Auditlog create event

          log = AuditLog.create!(account: assignee, task: task, amount: task.fee, event_type: "withdrawal").reload

          event = {
            event_id: SecureRandom.uuid,
            event_version: 1,
            event_time: DateTime.current,
            producer: "accounting",
            event_name: "AuditLogCreated",
            data: {
              public_id: log.public_id,
              account_id: log.account_id,
              task_id: log.task_id,
              amount: log.amount,
              event_type: log.event_type,
              created_at: log.created_at
            }
          }

          encoded_event = AVRO.encode(event, schema_name: "auditlogs_stream.created")
          Karafka.producer.produce_sync(topic: "auditlogs-stream", payload: encoded_event)
          # --------------------------------------------------------------------
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

          # --------------------------------------------------------------------
          # Balance update event

          event = {
            event_id: SecureRandom.uuid,
            event_version: 1,
            event_time: DateTime.current,
            producer: "accounting",
            event_name: "AccountBalanceUpdated",
            data: {
              public_id: assignee.public_id,
              balance: assignee.balance
            }
          }

          encoded_event = AVRO.encode(event, schema_name: "accounts_stream.balance_updated")
          Karafka.producer.produce_sync(topic: "accounts-stream", payload: encoded_event)
          # --------------------------------------------------------------------

          # --------------------------------------------------------------------
          # Auditlog create event

          log = AuditLog.create!(account: assignee, task: task, amount: task.reward, event_type: "deposit").reload

          event = {
            event_id: SecureRandom.uuid,
            event_version: 1,
            event_time: DateTime.current,
            producer: "accounting",
            event_name: "AuditLogCreated",
            data: {
              public_id: log.public_id,
              account_id: log.account_id,
              task_id: log.task_id,
              amount: log.amount,
              event_type: log.event_type,
              created_at: log.created_at
            }
          }

          encoded_event = AVRO.encode(event, schema_name: "auditlogs_stream.created")
          Karafka.producer.produce_sync(topic: "auditlogs-stream", payload: encoded_event)
          # --------------------------------------------------------------------
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
            # ------------------------------------------------------------------
            # Balance update event

            event = {
              event_id: SecureRandom.uuid,
              event_version: 1,
              event_time: DateTime.current,
              producer: "accounting",
              event_name: "AccountBalanceUpdated",
              data: {
                public_id: assignee.public_id,
                balance: assignee.balance
              }
            }

            encoded_event = AVRO.encode(event, schema_name: "accounts_stream.balance_updated")
            Karafka.producer.produce_sync(topic: "accounts-stream", payload: encoded_event)
            # ------------------------------------------------------------------

            # ------------------------------------------------------------------
            # Auditlog create event
            log = AuditLog.create!(account: assignee, task: task, amount: task.fee, event_type: "withdrawal").reload

            event = {
              event_id: SecureRandom.uuid,
              event_version: 1,
              event_time: DateTime.current,
              producer: "accounting",
              event_name: "AuditLogCreated",
              data: {
                public_id: log.public_id,
                account_id: log.account_id,
                task_id: log.task_id,
                amount: log.amount,
                event_type: log.event_type,
                created_at: log.created_at
              }
            }

            encoded_event = AVRO.encode(event, schema_name: "auditlogs_stream.created")
            Karafka.producer.produce_sync(topic: "auditlogs-stream", payload: encoded_event)
            # ------------------------------------------------------------------
          end
        end
      end
    end
  end

  # Run anything upon partition being revoked
  # def revoked
  # end

  # Define here any teardown things you want when Karafka server stops
  # def shutdown
  # end
end

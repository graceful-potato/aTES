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
          task = Task.create!(public_id: payload["data"]["public_id"],
                             title: payload["data"]["title"],
                             jira_id: payload["data"]["jira_id"],
                             description: payload["data"]["description"],
                             completed_at: payload["data"]["completed_at"],
                             assignee_id: payload["data"]["assignee_id"],
                             fee: payload["data"]["fee"],
                             reward: payload["data"]["reward"],
                             created_at: payload["data"]["created_at"])

          assignee = task.assignee
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
          # Вопрос. Возможно стоит в TaskCompleted ивент класть reward поле?
          # С reward полем мы сможем создать "заглушку" таски если например по
          # какой-то причине мы получаем ивент TaskCompleted перед TaskAdded.
          task = Task.find_by!(public_id: payload["data"]["public_id"])
          task.update(completed_at: payload["data"]["completed_at"])
          assignee = task.assignee
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
        # Тут тот же вопрос, что и в TaskCompleted.
        ActiveRecord::Base.transaction do
          payload["data"].each do |task|
            task = Task.find_by!(public_id: task["public_id"])
            assignee = Account.find_or_create_by(public_id: task["assignee_id"])
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
            # Auditlog create event
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

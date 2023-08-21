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
      when "TaskCompleted"
        ActiveRecord::Base.transaction do
          assignee = Account.find_or_create_by(public_id: payload["data"]["assignee_id"])
          task = Task.find_or_create_by(public_id: payload["data"]["public_id"]) do |t|
            t.reward = payload["data"]["reward"]
            t.completed_at = payload["data"]["completed_at"]
            t.assignee = assignee
          end
        end
      when "TasksShuffled"
        ActiveRecord::Base.transaction do
          payload["data"].each do |task_hash|
            assignee = Account.find_or_create_by(public_id: task_hash["assignee_id"])

            task = Task.find_or_create_by(public_id: task_hash["public_id"]) do |t|
              t.fee = task_hash["fee"]
            end

            task.update(assignee: assignee)
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

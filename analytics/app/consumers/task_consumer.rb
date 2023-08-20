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
        Task.create!(public_id: payload["data"]["public_id"],
                     title: payload["data"]["title"],
                     jira_id: payload["data"]["jira_id"],
                     description: payload["data"]["description"],
                     completed_at: payload["data"]["completed_at"],
                     assignee_id: payload["data"]["assignee_id"],
                     fee: payload["data"]["fee"],
                     reward: payload["data"]["reward"],
                     created_at: payload["data"]["created_at"])
      when "TaskCompleted"
        ActiveRecord::Base.transaction do
          task = Task.find_by!(public_id: payload["data"]["public_id"])
          task.update(completed_at: payload["data"]["completed_at"])
        end
      when "TasksShuffled"
        ActiveRecord::Base.transaction do
          payload["data"].each do |t|
            task = Task.find_by!(public_id: t["public_id"])
            task.update(assignee_id: t["assignee_id"])
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

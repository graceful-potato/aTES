json.account do
  json.public_id current_account.public_id
  json.full_name current_account.full_name
  json.email current_account.email
  json.role current_account.role
  json.balance current_account.balance
end

json.history @logs do |log|
  json.date log.created_at
  json.type log.event_type
  json.amount log.amount
  if log.task_id
    json.task do
      json.task_id log.task.public_id
      json.title log.task.title
      json.jira_id log.task.jira_id
      json.description log.task.description
      json.completed_at log.task.completed_at
      json.fee log.task.fee
      json.reward log.task.reward
    end
  end
end

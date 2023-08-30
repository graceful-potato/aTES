json.account do
  json.public_id current_account.public_id
  json.full_name current_account.full_name
  json.email current_account.email
  json.role current_account.role
  json.balance current_account.balance
end

json.history @transactions do |transaction|
  json.date transaction.created_at
  json.type transaction.kind
  case transaction.direction
  when "credit"
    json.amount transaction.credit
  when "debit"
    json.amount transaction.debit
  end
  if transaction.task_id
    json.task do
      json.task_id transaction.task.public_id
      json.title transaction.task.title
      json.jira_id transaction.task.jira_id
      json.description transaction.task.description
      json.completed_at transaction.task.completed_at
      json.fee transaction.task.fee
      json.reward transaction.task.reward
    end
  end
end

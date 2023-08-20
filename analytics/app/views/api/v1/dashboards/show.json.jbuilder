json.total_earnings @today_withdrawals + @today_deposits
json.negative_balances_count @negative_balances_count
json.most_expensive_task do
  json.from @from
  json.to @to
  json.price @task.reward
end

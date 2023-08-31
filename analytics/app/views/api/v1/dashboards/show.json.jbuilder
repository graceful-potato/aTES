json.total_earnings @total
json.negative_balances_count @negative_balances_count
json.most_expensive_task do
  json.from @from
  json.to @to
  json.price @most_expensive_task.reward
end

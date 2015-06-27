json.array! @time_sheets do |ts|
  json.cache! ts do
    json.(ts, :note, :user_id, :billable, :id, :timer_running, :time_spent)
    json.set! :ticket_id, ts.workable.display_id
    json.partial! 'shared/utc_date_format', item: ts, add: { executed_at: :executed_at, start_time: :start_time }
  end
end

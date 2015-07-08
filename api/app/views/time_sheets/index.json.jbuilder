json.array! @time_sheets do |ts|
  json.cache! ts do
    json.(ts, :note, :user_id, :id)
    json.set! :ticket_id, ts.workable.display_id
    json.set! :time_spent, ts.api_time_spent
    json.partial! 'shared/boolean_format', boolean_fields: { billable: ts.billable, timer_running: ts.timer_running }
    json.partial! 'shared/utc_date_format', item: ts, add: { executed_at: :executed_at, start_time: :start_time }
  end
end

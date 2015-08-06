json.array! @items do |ts|
  json.cache! [controller_name, action_name, ts] do
    json.(ts, :billable, :note, :timer_running, :user_id, :id)
    json.set! :ticket_id, @display_id || ts.workable.display_id
    json.set! :time_spent, ts.api_time_spent
    json.partial! 'shared/utc_date_format', item: ts, add: { executed_at: :executed_at, start_time: :start_time }
  end
end

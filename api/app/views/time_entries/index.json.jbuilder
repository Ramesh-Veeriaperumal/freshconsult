json.array! @items do |ts|
  json.cache! CacheLib.key(ts, params) do
    json.extract! ts, :billable, :note, :timer_running, :id, :created_at, :updated_at, :start_time, :executed_at
    json.set! :agent_id, ts.user_id
    json.set! :ticket_id, @ticket.try(:display_id) || ts.workable.display_id
    json.set! :time_spent, TimeEntryDecorator.format_time_spent(ts.time_spent)
  end
end

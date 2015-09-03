json.(@item, :id, :billable, :note, :timer_running)
json.set! :agent_id, @item.user_id
json.set! :ticket_id, @item.workable.display_id
json.set! :time_spent, @item.format_time_spent
json.partial! 'shared/utc_date_format', item: @item, add: { start_time: :start_time, executed_at: :executed_at }

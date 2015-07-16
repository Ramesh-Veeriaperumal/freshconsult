json.(@item, :id, :note, :user_id)
json.set! :ticket_id, @item.workable.display_id
json.set! :time_spent, @item.api_time_spent
json.partial! 'shared/boolean_format', boolean_fields: { billable: @item.billable, timer_running: @item.timer_running }
json.partial! 'shared/utc_date_format', item: @item, add: { start_time: :start_time, executed_at: :executed_at }

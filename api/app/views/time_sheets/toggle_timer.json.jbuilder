json.(@time_sheet, :id, :billable, :note, :timer_running, :user_id)
json.set! :ticket_id, @time_sheet.workable_id
json.set! :time_spent, @time_sheet.api_time_spent
json.partial! 'shared/utc_date_format', item: @time_sheet, add: { start_time: :start_time, executed_at: :executed_at }

json.(@time_sheet, :id, :note, :user_id)
json.set! :ticket_id, @time_sheet.workable.display_id
json.set! :time_spent, @time_sheet.api_time_spent
json.partial! 'shared/boolean_format', boolean_fields: { billable: @time_sheet.billable, timer_running: @time_sheet.timer_running }
json.partial! 'shared/utc_date_format', item: @time_sheet, add: { start_time: :start_time, executed_at: :executed_at }

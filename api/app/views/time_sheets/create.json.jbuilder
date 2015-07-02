json.(@time_sheet, :id, :billable, :created_at, :executed_at, :note, :start_time, :timer_running, :updated_at, :user_id, :time_spent)
json.set! :ticket_id, @time_sheet.workable_id
json.partial! 'shared/utc_date_format', item: @time_sheet, add: { start_time: :start_time, executed_at: :executed_at }
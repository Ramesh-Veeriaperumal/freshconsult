json.extract! @item, :id, :billable, :note, :timer_running, :created_at, :updated_at, :start_time, :executed_at
json.set! :agent_id, @item.user_id
json.set! :ticket_id, @item.workable.display_id
json.set! :time_spent, TimeEntryDecorator.format_time_spent(@item.time_spent)
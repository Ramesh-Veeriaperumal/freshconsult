module Helpdesk::TimeSheetsHelper
  def clear_view_timers(page)
    if !@time_cleared.nil? && (@time_entry.ticket_id == @time_cleared.ticket_id)
      page.replace "timeentry_#{@time_cleared.id}", :partial => "/helpdesk/time_sheets/time_entry", :object => @time_cleared
    end
  end
end

module Wf::OperatorHelper

  def is_in name, filter_value
    method = :"option_in_ticket_for_#{name}"
    ticket_value = (respond_to?(method) ? send(method, []) : @ticket.send(name))
    filter_value == ticket_value.to_s
  end

  def due_by_op name, filter_value
    case filter_value.to_i
    when 1 # overdue
      @ticket.send(name) <= Time.now
    when 2 # today
      @ticket.send(name) >= Time.zone.now.beginning_of_day && @ticket.send(name) <= Time.zone.now.end_of_day
    when 3 # tomorrow
      @ticket.send(name) >= Time.zone.now.tomorrow.beginning_of_day && @ticket.send(name) <= Time.zone.now.tomorrow.end_of_day
    when 4 # next 8 hours
      @ticket.send(name) >= Time.now && @ticket.send(name) <= 8.hours.from_now
    end
  end

end

module Wf::OptionSelecter

  def select_random_option options, correct_option
    case options
    when Array
      options.select { |option_value, option_name| 
        return false if option_value == correct_option # trying to generate a negative test case
        return true unless option_value.is_a? Fixnum
        option_value > 0
      }.sample[0]
    when Hash
      (options.keys - [correct_option]).sample  # trying to generate a negative test case
    when ''
      raise 'Empty string for options'
    end
  end

  def select_correct_option name, options
    method = :"option_in_ticket_for_#{name}"
    respond_to?(method) ? send(method, options) : @ticket.send(name)
  end

  def option_in_ticket_for_due_by options
    options = {1 => 'Overdue', 4 => 'Next 8 hours', 2 => 'Today', 3 => 'Tomorrow'} # Re-ordering, its important
    options.find { |option_value, option_name| due_by_op(:due_by, option_value) }.first
  end

  def option_in_ticket_for_tags options
    @ticket.tags.first.name
  end

  def option_in_ticket_for_customers options
    @ticket.requester.customer_id
  end

  def option_in_ticket_for_products options
    @ticket.product_id
  end

  def option_in_ticket_for_requester options
    @ticket.requester_id
  end

end

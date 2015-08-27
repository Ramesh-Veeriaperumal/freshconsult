module ApiApplicationHelper
  def format_time_spent(time_spent)
    if time_spent.is_a? Numeric
      # converts seconds to hh:mm format say 120 seconds to 00:02
      hours, minutes = time_spent.divmod(60).first.divmod(60)
      #  formatting 9 to be displayed as 09
      format('%02d:%02d', hours, minutes)
    end
  end

  def ticket_field_choices(current_account, ticket_field)
    case ticket_field.field_type
    when 'custom_dropdown'
      ticket_field.picklist_values.collect(&:value)
    when 'default_priority'
      Hash[TicketConstants.priority_names]
    when 'default_source'
      Hash[TicketConstants.source_names]
    when 'default_status'
      api_statuses = Helpdesk::TicketStatus.status_objects_from_cache(current_account).map do|status|
        [
          status.status_id, [Helpdesk::TicketStatus.translate_status_name(status, 'name'),
                             Helpdesk::TicketStatus.translate_status_name(status, 'customer_display_name')]
        ]
      end
      Hash[api_statuses]
    when 'default_ticket_type'
      current_account.ticket_types_from_cache.collect(&:value)
    when 'default_agent'
      return Hash[current_account.agents_from_cache.collect { |c| [c.user.name, c.user.id] }]
    when 'default_group'
      Hash[current_account.groups_from_cache.collect { |c| [CGI.escapeHTML(c.name), c.id] }]
    when 'default_product'
      Hash[current_account.products_from_cache.collect { |e| [CGI.escapeHTML(e.name), e.id] }]
    else
      []
    end
  end

  def nested_choices(picklist_values)
    picklist_values.collect do |c|
      Hash[c.value, c.sub_picklist_values.collect do |x|
        Hash[x.value, x.sub_picklist_values.collect(&:value)]
      end]
    end
  end

  def pluralize_keys(input_hash)
    return_hash = {}
    input_hash.each { |key, value| return_hash[key.to_s.pluralize] = value } if input_hash
    return_hash
  end

  def csv_to_array(string_csv)
    string_csv.split(',') unless string_csv.nil?
  end

  def companies_custom_dropdown_choices(choices = [])
    choices.map { |x| x[:value] }
  end

  def contact_field_choices(contact_field)
    case contact_field.field_type.to_s
    when 'default_language', 'default_time_zone'
      contact_field.choices.map { |x| x.values.reverse }.to_h
    when 'custom_dropdown' # not_tested
      contact_field.choices.map { |x| x[:value] }
    else
      []
    end
  end

  def default_contact_field?(contact_field)
    contact_field.column_name == 'default'
  end

  def get_ticket_field_choices(tf)
    if tf.field_type == 'nested_field'
      @choices = nested_choices(tf.picklist_values)
    else
      @choices = ticket_field_choices(Account.current, tf)
    end
    @choices
  end
end

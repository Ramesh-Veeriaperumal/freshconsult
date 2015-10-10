module HelpdeskReports::Util::Ticket
  include HelpdeskReports::Constants::Ticket

  def reverse_mapping_required? field
    return true if valid_field_name?(field) and [101, 107].include? REPORT_TYPE_BY_KEY[report_type]
    false
  end
  
  def valid_field_name? field
    field.to_s.starts_with?("ffs") || TICEKT_FIELD_NAMES.include?(field.to_sym)
  end

  def field_id_to_name_mapping(field_type)
    case field_type.to_sym
    when :status
      Helpdesk::TicketStatus.status_names_from_cache(Account.current).to_h
    when :ticket_type
      Account.current.ticket_types_from_cache.collect {|item| [item.id, item.value]}.to_h
    when :source
      TicketConstants.source_list
    when :priority
      TicketConstants.priority_list
    when :agent_id
      Account.current.agents_from_cache.collect { |au| [au.user.id, au.user.name] }.to_h
    when :group_id
      Account.current.groups_from_cache.collect { |g| [g.id, g.name]}.to_h
    when :product_id
      Account.current.products.collect {|p| [p.id, p.name]}.to_h
    when :company_id
      Account.current.companies_from_cache.collect { |au| [au.id, au.name] }.to_h
    else
      field_type.to_s.start_with?("ffs") ? flexifield_picklist_value_mapping(field_type) : {}
    end
  end  

  def flexifield_picklist_value_mapping field_name
    def_entry = Account.current.flexifield_def_entries.where(:flexifield_name => field_name).first
    def_entry ? picklist_values_hash(def_entry) : {}
  end
  
  def picklist_values_hash def_entry
    ticket_field = def_entry.ticket_field
    case ticket_field.field_type
      when "nested_field"
        picklist_values_for_nested_field ticket_field
      else
        ticket_field.picklist_values.collect{|c| [c.id, c.value]}.to_h
    end
  end
  
  def picklist_values_for_nested_field nested_field
    res_hash = {}
    case nested_field.level
      when 2
        parent_field = Account.current.ticket_fields_with_nested_fields.nested_fields.where(:id => nested_field.parent_id).first
        parent_field.picklist_values.each {|level_2| res_hash.merge!(level_2.sub_picklist_values.collect{|c| [c.id, c.value]}.to_h) }
      when 3
        parent_field = Account.current.ticket_fields_with_nested_fields.nested_fields.where(:id => nested_field.parent_id).first
        parent_field.picklist_values.each do |level_2|
          level_2.sub_picklist_values.each {|level_3| res_hash.merge!(level_3.sub_picklist_values.collect{|c| [c.id, c.value]}.to_h) }
        end
      else
        res_hash = nested_field.picklist_values.collect{|c| [c.id, c.value]}.to_h
    end
    res_hash
  end
  
  def date_part date, trend
    case trend
      when "doy" 
        date.yday
      when "w"
        date.cweek
      when "mon"
        date.strftime('%m').to_i
      when "qtr"
        (date.strftime('%m').to_i - 1 )/3 + 1
      when "y"
        date.year
    end
  end
  
end
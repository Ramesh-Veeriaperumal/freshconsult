module Search::KeywordSearch::Constants

  SUPPORTED_FIELDS = %w(agent created_at due_by status priority group type source product tags company requesters)

  def fetch_fields
    filter_fields = Hash.new.tap do |field_hash|
      SUPPORTED_FIELDS.each_with_index do |field, index|
        field_hash[field] = {
          position: index,
          name: I18n.t("helpdesk_search.#{field}"),
          accessor: field,
          options: field_choices(field.to_sym),
          container: field == "created_at" || field == "due_by" ? "date_picker" : "multi_select"
        }
      end
    end
    custom_fields = get_custom_fields
    last_pos = SUPPORTED_FIELDS.length + 1
    custom_fields.keys.each_with_index do | field , index|
          custom_fields[field][:position] = index + last_pos
    end
    @filter_fields = filter_fields.merge(custom_fields)
  end

  def field_choices(criteria_key)
    case criteria_key
      when :status
        return Helpdesk::TicketStatus.status_names_from_cache(current_account)
      when :type
        return current_account.ticket_types_from_cache.collect { |tt| [tt.value, tt.value] }
      when :source
        return TicketConstants.source_list.sort
      when :priority
        return TicketConstants.priority_list.sort
      when :group
        groups = []
        groups.concat(current_account.groups_from_cache.collect { |g| [g.id, g.name]})
        return groups
      when :product
        current_account.products.collect {|p| [p.id, p.name]}
      # when :responder_id
      #   agents = []
      #   agents.concat(current_account.agents_details_from_cache.collect { |au| [au.id, au.name] })
      #   return agents
      # when :customer_id
      #   return current_account.companies_from_cache.collect { |au| [au.id, au.name] }
      when :due_by
        return TicketConstants.due_by_list
      when :created_at
        return TicketConstants.created_within_list
      else
        return []
    end
  end
end

def id_from_field(tf)
    tf.flexifield_def_entry.flexifield_name
end

def get_custom_fields
  defs = {}
  #custom fields - checkbox and dropdown
  current_account.ticket_fields_from_cache.each do |col|
   if ["custom_checkbox"].include?(col.field_type)
     #defs[col.column_name] = {
       #:condition => col.column_name,
       #:name       =>  col.label,
       #:container  =>  "check_box",
       #:field_type =>  "custom",
       #:ff_name    =>  col.name,
       #:field_id       =>  col.id,
       #:accessor   => col.column_name
       #}
    elsif ["custom_dropdown"].include?(col.field_type)
      condition = col.column_name#id_from_field(col).to_sym
      defs[condition] = {
        :condition  =>  condition,
        :name       =>  col.label,
        :container  =>  "multi_select",
        :options    =>  col.dropdown_choices_with_id,
        :field_type =>  "custom",
        :ff_name    =>  col.name,
        :field_id       =>  col.id,
        :accessor   => condition
      }
    end
  end
  #nested fields
  current_account.nested_fields_from_cache.each do |col|
    nested_fields = []
    col.nested_ticket_fields(:include => :flexifield_def_entry).each do |nested_col|
      condition = id_from_field(nested_col).to_sym
      nested_fields.push({
        :condition  =>  condition,
        :name       =>  nested_col.label,
        :ff_name    =>  nested_col.name,
        })
    end

    condition = id_from_field(col).to_sym
    defs[condition] = {
      :condition      =>  condition,
      :name           =>  col.label,
      :container      =>  "nested_field",
      :options        =>  col.nested_choices_with_id,
      :nested_fields  =>  nested_fields,
      :field_type =>  "custom",
      :ff_name        =>  col.name,
      :field_id       =>  col.id,
      :accessor       => condition
    }
  end
  defs
end

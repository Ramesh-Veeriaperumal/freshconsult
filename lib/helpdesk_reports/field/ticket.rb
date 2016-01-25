module HelpdeskReports::Field::Ticket

  # Filter data for reports, Check template at the end of file
  def show_options(column_order, columns_keys_by_token, columns_option)
    
    #If Enterprise Addons is enabled, no need to check exclude filter
    unless Account.current.features_included?(:enterprise_reporting)
      excluded_filters = ReportsAppConfig::EXCLUDE_FILTERS[report_type]
      if excluded_filters
        column_order -=  excluded_filters[Account.current.subscription.subscription_plan.name]||[]
      end
    end
    
    @show_options ||= begin
      defs = {}
      @nf_hash = {}
      #default fields

      column_order.each do |name|
        container = columns_keys_by_token[name]
        defs[name] = {
          operator_list(container).to_sym => container,
          :condition  =>  name ,
          :name       =>  columns_option[name],
          :container  =>  "multi_select",
          :operator   =>  operator_list(container),
          :options    =>  default_choices(name),
          :value      =>  "",
          :field_type =>  "default",
          :ff_name    =>  "default",
          :active     =>  false
        }
        field_label_id_hash(defs[name])
      end

      #Custom fields
      Account.current.custom_dropdown_fields_from_cache.each do |col|
        condition = id_from_field(col).to_sym
        defs[condition] = {
          op_from_field(col).to_sym => container_from_field(col),
          :condition  =>  condition,
          :name       =>  col.label,
          :container  =>  "multi_select",
          :operator   =>  op_from_field(col),
          :options    =>  col.dropdown_choices_with_id,
          :value      =>  "",
          :field_type =>  "custom",
          :ff_name    =>  col.name,
          :active     =>  false
        }
        field_label_id_hash(defs[condition])
      end

      Account.current.nested_fields_from_cache.each do |col|
        nested_fields = []
        col.nested_ticket_fields(:include => :flexifield_def_entry).each do |nested_col|
          condition = id_from_field(nested_col).to_sym
          nested_fields.push({        
            operator_list('dropdown').to_sym => 'dropdown',
            :condition  =>  condition,
            :name       =>  nested_col.label,
            :container  =>  "nested_field",
            :operator   =>  operator_list('dropdown'),
            :options    =>  [],
            :value      =>  "" ,
            :field_type =>  "custom",
            :ff_name    =>  nested_col.name,
            :active     =>  false
            })
        end

        condition = id_from_field(col).to_sym
        defs[condition] = {
          op_from_field(col).to_sym => container_from_field(col),
          :condition      =>  condition,
          :name           =>  col.label,
          :container      =>  "nested_field",
          :operator       =>  op_from_field(col),
          :options        =>  col.nested_choices_with_id,
          :value          =>  "",
          :field_type     =>  "custom",
          :field_id       =>  col.id,
          :nested_fields  =>  nested_fields,
          :ff_name        =>  col.name,
          :active         =>  false
        }
        field_label_id_hash(defs[condition])
      end
      defs
    end
  end
  
  def field_label_id_hash(parent_field)
    @nf_hash[parent_field[:condition]] = parent_field[:options].collect{|op| [op.first, op.second]}.to_h
    (parent_field[:nested_fields]||[]).each_with_index do |nf, index|
      helper = []
      if index == 0
        parent_field[:options].each{|op| helper << op.third.collect{|i| [i.first, i.second]}}
      else
        parent_field[:options].each{|op| op.third.each{|nested_op| helper << nested_op.third.collect{|i| [i.first, i.second]}}}
      end
      @nf_hash[nf[:condition]] = helper.flatten(1).to_h
    end
  end


  def id_from_field(tf)
    tf.flexifield_def_entry.flexifield_name
  end

  def container_from_field(tf)
    tf.field_type.gsub('custom_', '').gsub('nested_field','dropdown')
  end

  def op_from_field(tf)
    operator_list(container_from_field(tf))
  end

  def operator_list(name)
    containers = Wf::Config.data_types[:helpdesk_tickets][name]
    container_klass = Wf::Config.containers[containers.first].constantize
    container_klass.operators.first
  end

  #Adding None as extra options.
  def default_choices(field)
    none_choice = [:priority,:status,:source].include?(field) ? "" : [-1,"-None-"]
    choice_hash = get_default_choices(field)
    choice_hash.unshift(none_choice) if !choice_hash.empty? && !none_choice.empty?
    choice_hash
  end

  def get_default_choices(field)  
    case field.to_sym
    when :status
      Helpdesk::TicketStatus.status_names_from_cache(Account.current)
    when :ticket_type
      Account.current.ticket_types_from_cache.collect { |tt| [tt.id, tt.value] }
    when :source
      TicketConstants.source_list.sort
    when :priority
      TicketConstants.priority_list.sort
    when :agent_id
      Account.current.agents_from_cache.collect { |au| [au.user.id, au.user.name] }
    when :group_id
      Account.current.groups_from_cache.collect { |g| [g.id, g.name]}
    when :product_id
      Account.current.products.collect {|p| [p.id, p.name]}
    when :company_id
      Account.current.companies_from_cache.collect { |au| [au.id, au.name] }
    else
      []
    end
  end

end

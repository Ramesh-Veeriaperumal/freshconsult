# encoding: utf-8
module Search::TicketSearch

  NONE_VALUE = -1

  META_DATA_KEYS = ["requester_id", "owner_id", "helpdesk_tags.name"]

  def show_options ( column_order = TicketConstants::DEFAULT_COLUMNS_ORDER,
   columns_keys_by_token = TicketConstants::DEFAULT_COLUMNS_KEYS_BY_TOKEN,
    columns_option = TicketConstants::DEFAULT_COLUMNS_OPTIONS)
     @show_options ||= begin
      defs = []
      i = 0
      #default fields

      column_order.each do |name|
        next if [:frDueBy, :nr_due_by].include?(name) && (!defined?(params) || params[:version].to_s != 'private')
        
        cont = columns_keys_by_token[name]
        defs.insert(i,{ get_op_list(cont).to_sym => cont  , 
                        :condition => name , 
                        :name => columns_option[name], 
                        :container => cont,     
                        :operator => get_op_list(cont), 
                        :options => get_default_choices(name), 
                        :value => "", 
                        :f_type => :default, 
                        :ff_name => "default"  })
        i = i+ 1
      end
      #Custom fields
      Account.current.custom_dropdown_fields_from_cache.each do |col|
        defs.insert(i,{get_op_from_field(col).to_sym => get_container_from_field(col),
                        :condition => get_id_from_field(col).to_sym ,
                        :name => col.label , 
                        :container => get_container_from_field(col),     
                        :operator => get_op_from_field(col), 
                        :options => get_custom_choices(col), 
                        :value => "", 
                        :ff_name => col.name  
                      })
        i = i+ 1     
      end 

      Account.current.nested_fields_from_cache.each do |col|
        nested_fields = []

        col.nested_fields_with_flexifield_def_entries.each do |nested_col|
          nested_fields.push({get_op_list('dropdown').to_sym => 'dropdown',
                              :condition => get_id_from_field(nested_col).to_sym ,
                              :name => nested_col.label , 
                              :container => 'dropdown',     
                              :operator => get_op_list('dropdown'), 
                              :options => [], 
                              :value => "" , 
                              :field_type => "nested_field", 
                              :ff_name => nested_col.name 
                            })     
        end

        defs.insert(i,{get_op_from_field(col).to_sym => get_container_from_field(col),
                        :condition => get_id_from_field(col).to_sym, 
                        :name => col.label , 
                        :container => get_container_from_field(col), 
                        :operator => get_op_from_field(col), 
                        :options => col.nested_choices, 
                        :value => "" , 
                        :field_type => "nested_field", 
                        :field_id => col.id, 
                        :nested_fields => nested_fields, 
                        :ff_name => col.name 
                      })
        i = i+ 1
      end

      defs
    end
  end


  def archive_show_options ( column_order = TicketConstants::ARCHIVE_DEFAULT_COLUMNS_ORDER,
   columns_keys_by_token = TicketConstants::ARCHIVE_DEFAULT_COLUMNS_KEYS_BY_TOKEN,
    columns_option = TicketConstants::ARCHIVE_DEFAULT_COLUMNS_OPTIONS)
     @show_options ||= begin
      defs = []
      i = 0
      #default fields

      column_order.each do |name|
        cont = columns_keys_by_token[name]
        defs.insert(i,{ get_op_list(cont).to_sym => cont  , 
                        :condition => name , 
                        :name => columns_option[name], 
                        :container => cont,     
                        :operator => get_op_list(cont), 
                        :options => get_default_choices(name), 
                        :value => "", 
                        :f_type => :default, 
                        :ff_name => "default"  })
        i = i+ 1
      end
      defs
    end
  end
  
  
  def get_id_from_field(tf)
    if Account.current.ticket_field_limit_increase_enabled?
      "#{Helpdesk::Filters::CustomTicketFilter::TICKET_FIELD_DATA}.#{tf.flexifield_def_entry.flexifield_name}"
    else
      "#{Helpdesk::Filters::CustomTicketFilter::FLEXIFIELDS}.#{tf.flexifield_def_entry.flexifield_name}"
    end
  end
  
  def get_container_from_field(tf)
    tf.field_type.gsub('custom_', '').gsub('nested_field','dropdown')
  end
  
  def get_op_from_field(tf)
    get_op_list(get_container_from_field(tf))    
  end
  
  def get_op_list(name)
    name = name.eql?('date_time') ? 'datetime' : name
    containers = Wf::Config.data_types[:helpdesk_tickets][name]
    container_klass = Wf::Config.containers[containers.first].constantize
    container_klass.operators.first   
  end
  
  def get_custom_choices(tf)
    [[NONE_VALUE, I18n.t("filter_options.none")]].concat(tf.dropdown_choices_with_name)
  end

  def get_custom_choices_by_id(tf)
    [[NONE_VALUE, nil]].concat(tf.dropdown_choices_with_picklist_id)
  end

  def get_default_choices(criteria_key)
    if criteria_key == :status
      statuses = [[0, I18n.t("filter_options.unresolved")]]
      return statuses.concat(Helpdesk::TicketStatus.status_names_from_cache(Account.current))
    end

    if criteria_key == :ticket_type
      types = [[NONE_VALUE, I18n.t("filter_options.none")]]
      return types.concat(Account.current.ticket_types_from_cache.collect { |tt| [tt.value, tt.value] })
    end

    if criteria_key == :source
      return TicketConstants.source_list.sort
    end

    if criteria_key == :priority
      return TicketConstants.priority_list.sort
    end

    if criteria_key == :sl_skill_id and Account.current.skill_based_round_robin_enabled?
      skills = Account.current.skills_trimmed_version_from_cache.collect {|au| [au.id, au.name]}
      return [[NONE_VALUE, I18n.t("filter_options.none")]] + skills if skills.length > 0 
    end

    if criteria_key == :responder_id
      agents = [[0, I18n.t("helpdesk.tickets.add_watcher.me")]]
      agents.concat(Account.current.agents_details_from_cache.collect { |au| [au.id, au.name] })      
      return agents.push([NONE_VALUE, I18n.t("filter_options.unassigned")])
    end

    if criteria_key == :group_id
      groups = [[0, I18n.t('filter_options.mygroups')]]
      groups.concat(Account.current.groups_from_cache.collect { |g| [g.id, CGI.escapeHTML(g.name)]})
      return groups.push([NONE_VALUE, I18n.t("filter_options.unassigned")])
    end

    if criteria_key == "helpdesk_schema_less_tickets.product_id" || criteria_key == :product_id
      products = Account.current.products_from_cache
      products_list = products.present? ? [[NONE_VALUE, I18n.t("filter_options.none")]] : []
      return products_list.concat(products.collect { |au| [au.id, CGI.escapeHTML(au.name)] })
    end

    if [:due_by, :frDueBy, :nr_due_by].include?(criteria_key) && Account.current.sla_management_enabled?
      if criteria_key != :nr_due_by || Account.current.next_response_sla_enabled?
        return (defined?(params) && params[:version].to_s == 'private') ? TicketConstants.due_by_list : TicketConstants.due_by_list.slice(*TicketConstants::OLD_DUE_BY_TYPES)
      end
    end

    if criteria_key == "helpdesk_tags.name"
      if @current_options && @current_options.has_key?("helpdesk_tags.name")
        tag_name = @current_options["helpdesk_tags.name"].split(',')
        if tag_name
          tags     = Account.current.tags.where(name: tag_name) 
          @selected_tags = tags.any? ? tags : nil
        end
      end
      
      return @selected_tags || [[1, ""]]
    end

    if criteria_key == :owner_id
      if @current_options && @current_options.has_key?("owner_id")
        company_id = @current_options["owner_id"].split(',').map(&:to_i)
      end
      @selected_companies = Account.current.companies.where(id: company_id) if company_id
      @selected_companies << NONE_VALUE if company_id and company_id.include?(NONE_VALUE)
      
      return @selected_companies || [[1,""]]
    end

    if criteria_key == :requester_id
      if @requester_id_param
        requester_id = @requester_id_param.lines.to_a
      elsif @current_options && @current_options.has_key?("requester_id")
        requester_id = @current_options["requester_id"].split(',')
      end
      @selected_requesters = Account.current.users.where(id: requester_id) if requester_id
      
      return @selected_requesters || [[1,""]]
    end

    if criteria_key == :created_at
      return TicketConstants.created_within_list
    end

    if criteria_key == :association_type
      return TicketConstants.association_type_filter_list
    end

    return []
  end

  def filters_meta_data(c_hash)
    meta_hash = {}
    c_hash.each do |key, value|
      next unless META_DATA_KEYS.include?(key.to_s)
      ids = value.split(",")
      next if ids.blank?
      meta_hash[key] =  (key.to_s == "helpdesk_tags.name" ? tags_meta_data(key, ids) : customers_meta_data(key, ids))
    end
    meta_hash
  end
  

  def customers_meta_data(key, ids)
    association = (key.to_s == "requester_id" ? "users" : "companies")
    Account.current.safe_send(association).where(id: ids ).select("id, name").map { |o| {id: o.id, value: o.name, text: o.name}}
  end

  def tags_meta_data(key, values)
    Account.current.tags.where(name: values).select("id, name").map { |o| {id: o.name, value: o.name, text: o.name}}
  end
end

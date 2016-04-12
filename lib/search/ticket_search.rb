# encoding: utf-8
module Search::TicketSearch

  NONE_VALUE = -1

  def show_options ( column_order = TicketConstants::DEFAULT_COLUMNS_ORDER,
   columns_keys_by_token = TicketConstants::DEFAULT_COLUMNS_KEYS_BY_TOKEN,
    columns_option = TicketConstants::DEFAULT_COLUMNS_OPTIONS)
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
  
  
  def get_id_from_field(tf)
    "flexifields.#{tf.flexifield_def_entry.flexifield_name}"
  end
  
  def get_container_from_field(tf)
    tf.field_type.gsub('custom_', '').gsub('nested_field','dropdown')
  end
  
  def get_op_from_field(tf)
    get_op_list(get_container_from_field(tf))    
  end
  
  def get_op_list(name)
    containers = Wf::Config.data_types[:helpdesk_tickets][name]
    container_klass = Wf::Config.containers[containers.first].constantize
    container_klass.operators.first   
  end
  
  def get_custom_choices(tf)
    [[NONE_VALUE, I18n.t("filter_options.none")]].concat(tf.dropdown_choices_with_name)
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

    if criteria_key == "helpdesk_schema_less_tickets.product_id"
      products = Account.current.products_from_cache
      products_list = products.present? ? [[NONE_VALUE, I18n.t("filter_options.none")]] : []
      return products_list.concat(products.collect { |au| [au.id, CGI.escapeHTML(au.name)] })
    end

    if criteria_key == :due_by
      return TicketConstants.due_by_list
    end

    if criteria_key == "helpdesk_tags.name"
      return Account.current.tags_from_cache.collect { |au| [au.name, CGI.escapeHTML(au.name)] }
    end

    if criteria_key == :owner_id
      if @current_options && @current_options.has_key?("owner_id")
        company_id = @current_options["owner_id"].split(',').map(&:to_i)
      end
      @selected_companies = Account.current.companies.find_all_by_id(company_id) if company_id
      @selected_companies << NONE_VALUE if company_id and company_id.include?(NONE_VALUE)

      return @selected_companies || [[1,""]]
    end

    if criteria_key == :requester_id
      if @requester_id_param
        requester_id = @requester_id_param.lines.to_a
      elsif @current_options && @current_options.has_key?("requester_id")
        requester_id = @current_options["requester_id"].split(',')
      end
      @selected_requesters = Account.current.users.find_all_by_id(requester_id) if requester_id
      return @selected_requesters || [[1,""]]
    end

    if criteria_key == :created_at
      return TicketConstants.created_within_list
    end

    return []
  end
  
end
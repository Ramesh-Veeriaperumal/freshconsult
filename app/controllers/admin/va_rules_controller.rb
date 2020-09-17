class Admin::VaRulesController < Admin::AdminController
  include ModelControllerMethods
  include Va::Constants
  include Admin::AdvancedTicketing::FieldServiceManagement::Constant
  include Admin::Automation::WebhookValidations

  # skip_before_filter :check_automation_feature
  around_filter :escape_html_entities_in_json
  before_filter :load_config, :only => [:new, :edit, :clone_rule]
  before_filter :set_filter_data, :only => [ :create, :update ]
  before_filter :hide_password_in_webhook, :only => [:edit]
  before_filter :parse_action_data, :only => [:create, :update]
  before_filter :validate_email_template, :only => [:create, :update]
  before_filter :validate_active_param, :only => [:activate_deactivate]
  # TODO-RAILS3 password moved to application.rb but need to check action_data
  # filter_parameter_logging :action_data, :password
  
  include AutomationControllerMethods
  include Helpdesk::ReorderUtility

  def activate_deactivate
    @va_rule = all_scoper.find(params[:id])
    @va_rule.assign_attributes({:active => params[:va_rule][:active]})
    @va_rule.save! if @va_rule.changed?
    type = params[:va_rule][:active] == "true" ? 'activation' : 'deactivation'

    respond_to do |format|
      format.html do
        flash[:highlight] = dom_id(@va_rule)
        flash[:notice] = t("flash.general.#{type}.success", :human_name => human_name)
        redirect_to :action => 'index'
      end
      format.json do
        render :json => { success: true }
      end
    end
  end

  def toggle_cascade
    if current_account.cascade_dispatcher_enabled?
      current_account.disable_setting(:cascade_dispatcher)
    else
      current_account.enable_setting(:cascade_dispatcher)
    end
    current_account.reload
    render :nothing => true
  end

  protected

    def parse_action_data
      @va_rule.action_data = params[:action_data].blank? ? [] : (ActiveSupport::JSON.decode params[:action_data])
      if va_rules_controller? or observer_rules_controller?
        @va_rule.action_data.each do |action|
          if action["name"] == "trigger_webhook" && Account.current.webhook_blacklist_ip_enabled? && !valid_webhook_url?(action["url"])
            flash[:error] = t("admin.va_rules.webhook.invalid_url") 
            error = true
          end
          if action["custom_headers"].present?
            headers = RailsSanitizer.full_sanitizer.sanitize(action["custom_headers"])
            headers = headers.split(/[\r\n]+/).map { |x| x.split(":", 2).map(&:strip).reject { |x| x == "" } }
            error = false
            action["custom_headers"] = {}
            headers.each do |key, val|
              if (key.blank? or val.blank?)
                flash[:error] = t("admin.va_rules.webhook.custom_headers_pair_mismatch")
                error = true
                break
              end
              action["custom_headers"].merge!({key => val})
            end
            if action["custom_headers"].keys.count > MAX_CUSTOM_HEADERS
              flash[:error] = t("admin.va_rules.webhook.custom_headers_limit_error", :limit => MAX_CUSTOM_HEADERS)
              error = true
            end
          end
          if error
            load_config
            edit_data
            render :action => params[:action] == 'update' ? 'edit' : 'new'
          end
        end
      end
    end

    def validate_active_param
      va_rule_active = params[:va_rule][:active]
      unless ["true", "false"].include? va_rule_active
        respond_to do |format|
          format.json do
            render :json => { success: false }
          end
        end
      end
    end

    def scoper
      current_account.va_rules
    end

    def all_scoper
      current_account.all_va_rules
    end

    def human_name
      "Dispatch'r rule"
    end

    def set_filter_data
      @va_rule.filter_data = params[:filter_data].blank? ? [] : ActiveSupport::JSON.decode(params[:filter_data])
      set_nested_fields_data @va_rule.filter_data
    end

    def edit_data
      filter_data = change_to_in_operator(@va_rule.filter_data)
      @filter_input = ActiveSupport::JSON.encode filter_data
      super
    end

    def change_to_in_operator(filter_data)
      fields = current_account.fields_with_in_operators
      filter_data.each do |f|
        f.symbolize_keys!
        dropdown_fields = f[:evaluate_on].present? ? fields[f[:evaluate_on]] : fields["ticket"]
        if (f[:operator] == "is" || f[:operator] == "is_not") && (dropdown_fields.include?(f[:name]))
          f[:operator] = (f[:operator] == "is") ? "in" : "not_in"
        end
      end
      filter_data
    end

    def build_object #Some bug with build during new, so moved here from ModelControllerMethods
      @va_rule = params[:va_rule].nil? ? VaRule.new : scoper.build(params[:va_rule])
    end

    def load_object
      @va_rule = all_scoper.find(params[:id])
      @obj = @va_rule #Destroy of model-controller-methods needs @obj
    end

    def get_event_performer
      [[-2, I18n.t('ticket_creating_agent')]]
    end

    def load_config
      super
      
      @agents = none_option + agents_list
      @groups = none_option + groups_list_from_cache
      load_internal_group_agents if allow_shared_ownership_fields? 

      tag_ids = []
      @va_rule.filter_array.each do |f|
        f.symbolize_keys!
        if(f[:evaluate_on].present? and f[:evaluate_on] == "ticket" and f[:name] == "tag_ids")
          tag_ids = tag_ids + f[:value]
        end
      end

      @tag_hash = {}
      current_account.tags.where(id: tag_ids).each {|t| @tag_hash[t.id] = CGI.escapeHTML(t.name)}
      @tag_hash = ActiveSupport::JSON.encode @tag_hash

      filter_hash = {}
      add_ticket_fields filter_hash

      if supervisor_rules_controller?
        @is_supervisor = true
      else
        add_contact_fields filter_hash
        add_company_fields filter_hash
      end
      @filter_defs  = ActiveSupport::JSON.encode filter_hash

      operator_types = OPERATOR_TYPES.clone
      
      if supervisor_rules_controller?
        operator_types[:number] = ["is", "is_not"]
        operator_types[:decimal] = ["is", "is_not"]
      end
      @op_types     = ActiveSupport::JSON.encode operator_types
      @op_list      = ActiveSupport::JSON.encode va_operator_list
      @op_label     = ActiveSupport::JSON.encode va_alternate_label
    end

    def add_ticket_fields filter_hash
      filter_hash['ticket']   = [
        { :name => -1, :value => t('click_to_select_filter') },
        { :name => "from_email", :value => t('requester_email'), :domtype => "autocompelete", 
          :data_url => requesters_search_autocomplete_index_path, :operatortype => "email",
          :condition => requester_email_enabled?},
        { :name => "to_email", :value => t('to_email'), :domtype => "text",
          :operatortype => "email" },
        { :name => "ticlet_cc", :value => t('ticket_cc'), :domtype => "text",
          :operatortype => "email", :condition => va_rules_controller? },
        { :name => -1, :value => "-----------------------" },
        { :name => "subject", :value => t('ticket.subject'), :domtype => "text",
          :operatortype => "text" },
        { :name => "description", :value => t('description'), :domtype => "text",
          :operatortype => "text", :condition => !supervisor_rules_controller? },
        { :name => "subject_or_description", :value =>  t('subject_or_description'), 
          :domtype => "text", :operatortype => "text", :condition => !supervisor_rules_controller? },
        { :name => "last_interaction", :value => I18n.t('last_interaction'), :domtype => "text",
          :operatortype => "text", :condition => observer_rules_controller? },
        { :name => "priority", :value => t('ticket.priority'), :domtype => dropdown_domtype, 
          :choices => TicketConstants.priority_list.sort, :operatortype => "choicelist" },
        { :name => "ticket_type", :value => t('ticket.type'), :domtype => dropdown_domtype, 
          :choices => ticket_type_values_with_none, 
          :operatortype => "choicelist" },
        { :name => "status", :value => t('ticket.status'), :domtype => dropdown_domtype, 
          :choices => Helpdesk::TicketStatus.status_names(current_account), :operatortype => "choicelist"},
        { :name => "source", :value => t('ticket.source'), :domtype => dropdown_domtype, 
          :choices => source_choices.sort, :operatortype => "choicelist" },
        { :name => "product_id", :value => t('admin.products.product_label_msg'), :domtype => dropdown_domtype, 
          :choices => none_option+@products, :operatortype => "choicelist",
          :condition => multi_product_account? },
        { :name=> "created_at", :value => t('ticket.created_during.title'), :domtype => "business_hours_dropdown",
          :operatortype => "date_time", :choices => VAConfig::CREATED_DURING_NAMES_BY_KEY.sort, :business_hours_choices => business_hours_for_account,
          :condition => va_rules_controller? },
        { :name => "responder_id", :value => I18n.t('ticket.agent'), :domtype => dropdown_domtype,
          :operatortype => "object_id", :choices => @agents },
        { :name => "group_id", :value => I18n.t('ticket.group'), :domtype => dropdown_domtype,
          :operatortype => "object_id", :choices => @groups },
        { :name => "internal_agent_id", :value => I18n.t('ticket.internal_agent'), :domtype => dropdown_domtype,
          :operatortype => "object_id", :choices => @internal_agents_condition, :condition => allow_shared_ownership_fields? },
        { :name => "internal_group_id", :value => I18n.t('ticket.internal_group'), :domtype => dropdown_domtype,
          :operatortype => "object_id", :choices => @internal_groups, :condition => allow_shared_ownership_fields? },
        { :name => "tag_ids", :value => t('ticket.tag_condition'), :domtype => "autocomplete_multiple_with_id", 
          :data_url => tags_search_autocomplete_index_path, :operatortype => "object_id_array",
          :condition => !supervisor_rules_controller?, :autocomplete_choices => @tag_hash },
        { :name => -1, :value => "-----------------------",
          :condition => (contact_field_enabled? || company_field_enabled?) },
        { :name => "contact_name", :value => t('contact_name'), :domtype => "text",
          :operatortype => "text", :condition =>  contact_field_enabled?},
        { :name => "company_name", :value => t('company_name'), :domtype => "text",
          :operatortype => "text", :condition =>  company_field_enabled?}
      ]

      filter_hash['ticket'] = filter_hash['ticket'].select{ |filter| filter.fetch(:condition, true) }
      add_time_based_filters filter_hash['ticket']
      add_ticket_state_filters filter_hash['ticket']
      add_custom_filters filter_hash['ticket']
    end

    def add_time_based_filters filter_hash
      if supervisor_rules_controller?
        filter_hash.push *time_based_filters
      end
    end

    def time_based_filters
      [
        { :name => -1, :value => "-----------------------"  },
        { :name => "created_at", :value => I18n.t('ticket.created_at'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "pending_since", :value => I18n.t('ticket.pending_since'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "resolved_at", :value => I18n.t('ticket.resolved_at'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "closed_at", :value => I18n.t('ticket.closed_at'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "opened_at", :value => I18n.t('ticket.opened_at'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "first_assigned_at", :value => I18n.t('ticket.first_assigned_at'),
          :domtype => "number", :operatortype => "hours" },
        { :name => "assigned_at", :value => I18n.t('ticket.assigned_at'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "requester_responded_at", :value => I18n.t('ticket.requester_responded_at'),
          :domtype => "number", :operatortype => "hours" },
        { :name => "agent_responded_at", :value => I18n.t('ticket.agent_responded_at'),
          :domtype => "number", :operatortype => "hours" },
        { :name => "frDueBy", :value => I18n.t('ticket.first_response_due'),
          :domtype => "number", :operatortype => "hours" },
        { :name => "due_by", :value => I18n.t('ticket.due_by'), :domtype => "number",
          :operatortype => "hours" }
      ]
    end

    def add_ticket_state_filters filter_hash
      if supervisor_rules_controller? || observer_rules_controller?
        filter_hash.push *ticket_state_filters
      end
    end

    def ticket_state_filters
      # operatortype should not be named hours for a count type.. need to change
      [
        { :name => -1, :value => "-----------------------"  },
        { :name => "inbound_count", :value => I18n.t('ticket.inbound_count'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "outbound_count", :value => I18n.t('ticket.outbound_count'), :domtype => "number",
          :operatortype => "hours" }
      ]

    end

    def ticket_state_filters
      [
        { :name => -1, :value => "-----------------------"  },
        { :name => "inbound_count", :value => I18n.t('ticket.inbound_count'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "outbound_count", :value => I18n.t('ticket.outbound_count'), :domtype => "number",
          :operatortype => "hours" }
      ]
    end

    def ticket_field_filters_for_automations
      current_account.ticket_fields.non_encrypted_custom_fields.preload(:flexifield_def_entry)
    end


    def add_custom_filters filter_hash
      nested_special_case = [[ANY_VALUE[:with_none], t('any_val.any_value')], ['', t('none')]]
      nested_special_case << [ANY_VALUE[:without_none], t('any_val.excluding_none')]  if current_account.va_any_field_without_none_enabled?

      cf = ticket_field_filters_for_automations
      cf.select!{|field| field.flexifield_def_entry.flexifield_name.starts_with?('ff') } if supervisor_rules_controller?
      
      # Skipping Fields reserved for FSM and custom Datetime fields.
      cf.reject! { |field| field.fsm_reserved_custom_field? || field.custom_date_time_field? }
      unless cf.blank?
        filter_hash.push({ :name => -1,
                           :value => "---------------------"
                           })
        cf.each do |field|
          next if supervisor_rules_controller? and !Account.current.launched?(:supervisor_multi_line_field) and field.field_type == 'custom_paragraph'
          filter_hash.push({
                             :id => field.id,
                             :name => field.name,
                             :value => field.label,
                             :field_type => field.field_type,
                             :domtype => (field.field_type == "nested_field") ? "nested_field" : 
                                    field.flexifield_def_entry.flexifield_coltype == "dropdown" ? dropdown_domtype : field.flexifield_def_entry.flexifield_coltype,
                             :choices =>  (field.field_type == "nested_field") ? (field.nested_choices_with_special_case nested_special_case) : none_option+field.picklist_values.collect { |c| [c.value, c.value ] },
                             :action => "set_custom_field",
                             :operatortype => CF_OPERATOR_TYPES.fetch(field.field_type, "text"),
                             :nested_fields => nested_fields(field)
          })
        end
      end
    end

    def add_contact_fields filter_hash
      filter_hash['requester'] = [
        { :name => -1, :value => t('click_to_select_filter') },
        { :name => "email", :value => t('requester_email'), :domtype => "autocompelete", 
          :data_url => requesters_search_autocomplete_index_path, :operatortype => "email" },
        { :name => "name", :value => t('requester_name'), :domtype => "text", 
          :operatortype => "text" },
        { :name => "job_title", :value => t('requester_title'), :domtype => "text", 
          :operatortype => "text" },
        { :name => "time_zone", :value => t('requester_time_zone'), :domtype => dropdown_domtype, 
          :choices => AVAILABLE_TIMEZONES, :operatortype => "choicelist",
          :condition => multi_timezone_account? },
        { name: 'language', value: t('requester_language'), domtype: dropdown_domtype,
          choices: AVAILABLE_LOCALES, operatortype: 'choicelist',
          condition: multi_language_account? },
        { name: 'segments', value: t('requester_segment'), domtype: dropdown_domtype,
          choices: segments(:contact_filters), operatortype: 'choicelist',
          condition: current_account.segments_enabled? },
        { name: 'twitter_followers_count', value: t('requester_twitter_followers_count'), domtype: 'number',
          operatortype: 'number',
          condition: current_account.twitter_field_automation_enabled? },
        { name: 'twitter_profile_status', value: t('requester_twitter_profile_status'), domtype: 'string',
          operatortype: 'checkbox', condition: current_account.twitter_field_automation_enabled? }
      ]
      add_customer_custom_fields filter_hash['requester'], "contact"
      filter_hash['requester'] = filter_hash['requester'].select{ |filter| filter.fetch(:condition, true) }
    end

    def add_company_fields filter_hash
      filter_hash['company'] = [
        { :name => -1, :value => t('click_to_select_filter') },
        { :name => "name", :value => t('company_name'), :domtype => "autocomplete_multiple", 
          :data_url => companies_search_autocomplete_index_path, :operatortype => "choicelist" },
        { name: 'domains', value: t('company_domain'), domtype: 'text',
          operatortype: 'choicelist' },
        { name: 'segments', value: t('company_segment'), domtype: dropdown_domtype,
          choices: segments(:company_filters), operatortype: 'choicelist',
          condition: current_account.segments_enabled? }
      ]
      add_tam_company_fields filter_hash['company'] if current_account.tam_default_fields_enabled?
      add_customer_custom_fields filter_hash['company'], "company"
      filter_hash['company'] = filter_hash['company'].select{ |filter| filter.fetch(:condition, true) }
    end

    def segments(type)
      current_account.safe_send(type).map do |segment|
        [segment.id, segment.name]
      end
    end

    def add_customer_custom_fields filter_hash, type
      cf = current_account.safe_send("#{type}_form").safe_send("custom_#{type}_fields", true)
      unless cf.blank? 
        filter_hash.push({ :name => -1,
                          :value => "---------------------" 
                          })
        cf.each do |field|
          filter_hash.push({
            :id => field.id,
            :name => "#{field.name}",
            :value => field.label,
            :field_type => field.field_type,
            :domtype => (field.dom_type == :dropdown_blank) ? dropdown_domtype : field.dom_type,
            :choices => none_option+field.custom_field_choices.collect { |c| [c.value, c.value ] },
            :action => "set_custom_field",
            :operatortype => CF_CUSTOMER_TYPES.fetch(field.field_type.to_s, "text"),
            :nested_fields => nested_fields(field)
          })
        end
      end
    end

    def add_tam_company_fields filter_hash
      filter_hash.push(
        { :name => "health_score", :value => t('company.health_score'),
          :domtype => dropdown_domtype, :operatortype => "choicelist",
          :choices => none_option +
          company_field_choices(Company::DEFAULT_DROPDOWN_FIELD_MAPPINGS[:health_score])},
        { :name => "account_tier", :value => t('company.account_tier'),
          :domtype => dropdown_domtype, :operatortype => "choicelist",
          :choices => none_option +
          company_field_choices(Company::DEFAULT_DROPDOWN_FIELD_MAPPINGS[:account_tier])},
        { :name => "industry", :value => t('company.industry'),
          :domtype => dropdown_domtype, :operatortype => "choicelist",
          :choices => none_option +
          company_field_choices(Company::DEFAULT_DROPDOWN_FIELD_MAPPINGS[:industry])},
        { :name => "renewal_date", :value => t('company.renewal_date'),
          :domtype => "date", :operatortype => "date"}
        )
    end

    def hide_password_in_webhook
      @va_rule.hide_password!
    end

    def business_hours_for_account
      bhrs = []
      if current_account.multiple_business_hours_enabled?
        account_bhs = current_account.business_calendar.map{|bc| [bc.id,bc.name]}
        bhrs = account_bhs if account_bhs.size > 1
      end
      bhrs
    end

    def dropdown_domtype
      'multiple_select'
    end

    def source_choices
      # Since we don't enqueue the ticket in Dispatchr when the ticket is created through Outbound email, there is no need to show the option 'Outbound email' for 'Ticket Source' in the Dispatchr's Create/Edit page
      va_rules_controller? ? 
        TicketConstants.source_list.except(current_account.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]) :
                TicketConstants.source_list
    end

    def company_field_choices field_type
      current_account.company_form.default_drop_down_fields(field_type.to_sym).
        first.custom_field_choices.collect { |c| [c.value, CGI.unescapeHTML(c.value)] }
    end

    def requester_email_enabled?
      !supervisor_rules_controller? || contact_field_enabled?
    end

    def contact_field_enabled?
      supervisor_rules_controller? && current_account.launched?(:supervisor_contact_field)
    end

    def company_field_enabled?
      supervisor_rules_controller? && current_account.launched?(:supervisor_company_field)
    end
end

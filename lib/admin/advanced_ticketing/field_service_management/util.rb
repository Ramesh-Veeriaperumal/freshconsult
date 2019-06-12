module Admin::AdvancedTicketing::FieldServiceManagement
  module Util
    include Admin::AdvancedTicketing::FieldServiceManagement::Constant
    include Dashboard::Custom::CustomDashboardConstants
    include Helpdesk::Ticketfields::ControllerMethods
    include Cache::Memcache::Helpdesk::Section
    include GroupConstants

    def notify_fsm_dev(subject, message)
      message = {} unless message
      message[:environment] = Rails.env
      topic = SNS['field_service_management']
      DevNotification.publish(topic, subject, message.to_json) unless Rails.env.development? || Rails.env.test?
    end

    private

      def perform_fsm_operations
        create_service_task_field_type
        fsm_fields_to_be_created = fetch_fsm_fields_to_be_created
        reserve_fsm_custom_fields(fsm_fields_to_be_created)
        create_section(fsm_fields_to_be_created)
        create_field_agent_type
        create_field_group_type
        create_fsm_dashboard if Account.current.fsm_dashboard_enabled?
        expire_cache
      rescue StandardError => e
        log_operation_failure('Enable', e)
      end

      def log_operation_failure(operation, exception)
        msg = "#{operation} FSM feature failed"
        error_msg = "#{msg}, account id: #{Account.current.id}, message: #{exception.message}"
        Rails.logger.error error_msg
        NewRelic::Agent.notice_error(exception, description: error_msg)
        msg_param = { account_id: Account.current.id, message: exception.message }
        notify_fsm_dev(msg, msg_param)
      end

      def feature_fsm?
        cname_params[:name].to_sym == FSM_FEATURE
      end

      def create_service_task_field_type
        return if Account.current.ticket_types_from_cache.map(&:value).include?(SERVICE_TASK_TYPE)
        
        type_field = Account.current.ticket_fields.find_by_field_type('default_ticket_type')
        picklist_values = type_field.picklist_values
        picklist_choices = picklist_values.map { |picklist| { value: picklist.value, id: picklist.id, position: picklist.position, _destroy: 0 } }
        picklist_choices.push(value: SERVICE_TASK_TYPE, position: picklist_choices.size + 1, _destroy: 0)

        type_field_options = {
          choices: picklist_choices,
          picklist_values_attributes: picklist_choices,
          field_options: { "section_present": true }
        }

        raise "Couldn't create a new ticket type for service task" unless type_field.update_attributes(type_field_options)
      end

      # Reserve the required FSM custom fields. refer: CUSTOM_FIELDS_TO_RESERVE
      def reserve_fsm_custom_fields(fields_to_be_created)
        last_occupied_position = ticket_fields.count + 1
        fields_to_be_created.each_with_index do |custom_field, index|
          payload = custom_field_generator(custom_field.merge(position: last_occupied_position + index))
          create_field(payload, Account.current)
        end
      end

      def create_field(field_details, account)
        field_name = field_details.delete(:name)
        ff_def_entry = FlexifieldDefEntry.new ff_meta_data(field_details, account, true)
        field_details.merge!(flexifield_def_entry_details(ff_def_entry))

        ticket_field = ticket_fields.build(field_details)
        ticket_field.name = field_name
        ticket_field.flexifield_def_entry = ff_def_entry

        raise "Couldn't save ticket field" unless ticket_field.save
        ticket_field.insert_at(field_details[:position]) if field_details[:position].present?
      end

      def ticket_fields
        @ticket_fields ||= Account.current.ticket_fields_including_nested_fields
      end

      def custom_field_generator(options)
        payload = {
          type: options[:type],
          label: options[:label],
          field_type: options[:field_type],
          position: options[:position],
          name: "#{options[:name]}_#{Account.current.id}",
          label_in_portal: options[:label_in_portal],
          field_options: { "section" => true },
          description: '',
          active: true,
          required: options[:required] || false,
          required_for_closure: false,
          visible_in_portal: true,
          editable_in_portal: false,
          required_in_portal: false,
          flexifield_alias: options[:flexifield_alias]
        }
        payload.merge!(custom_dropdown_options) if options[:type] == 'dropdown'

        payload
      end

      def custom_dropdown_options
        { choices: FSM_DROPDOWN_OPTIONS, picklist_values_attributes: FSM_DROPDOWN_OPTIONS }
      end

      # create a dynamic section named "Service Task" and attach the reserved custom fields to them.
      def create_section(fields_to_be_created)
        # TODO: check for section limit.
        service_task_picklist = Account.current.ticket_fields.find_by_field_type('default_ticket_type').picklist_values.find_by_value(SERVICE_TASK_TYPE)
        picklist_id = service_task_picklist.id
        parent_ticket_field_id = service_task_picklist.pickable_id

        # Build Section picklist_mappings
        service_task_section = Account.current.sections.find_by_label(SERVICE_TASK_SECTION)
        unless service_task_section.present?
          service_task_section = Account.current.sections.build
          service_task_section.label = SERVICE_TASK_SECTION
          service_task_section.section_picklist_mappings.build(picklist_value_id: picklist_id)
        end

        # Build Section fields
        section_fields = []
        if service_task_section.section_fields.blank?
          fields_to_be_created = CUSTOM_FIELDS_TO_RESERVE
          fields_to_be_created.each do |field|
            field_data = Account.current.ticket_fields.find_by_name(field[:name]+ "_#{Account.current.id}")
            next if field_data.field_options["section"] 
            
            field_data.field_options = { "section" => true }
            field_data.save
          end
          ticket_type_field = Account.current.ticket_fields.find_by_name('ticket_type')
          if !ticket_type_field.field_options["section_present"]
            ticket_type_field.field_options = { "section_present" => true}
            ticket_type_field.save
          end
        end
        fields_to_be_created.each_with_index do |custom_field, index|
          field = Account.current.ticket_fields.find_by_name("#{custom_field[:name]}_#{Account.current.id}")
          section_fields << { parent_ticket_field_id: parent_ticket_field_id, ticket_field_id: field.id, position: index + 1 }
        end
        section_data = service_task_section
        section_fields.each do |section_field|
          section_data.section_fields.build(section_field)
        end
        section_data.save
      end

      def create_field_group_type
        if Account.current.group_types.find_by_name(FIELD_GROUP_NAME).nil?
          group_type = GroupType.create_group_type(Account.current, FIELD_GROUP_NAME)
          raise "Field group type did not get created" unless group_type
        end
      end

      def create_field_agent_type
        if Account.current.agent_types.find_by_name(FIELD_AGENT).nil?
          agent_type = AgentType.create_agent_type(Account.current, FIELD_AGENT)
          raise "Field agent type did not get created" unless agent_type
        end
      end
      
      def create_fsm_dashboard
        options = create_fsm_default_custom_filters
        dashboard_object = DashboardObjectConcern.new(I18n.t("fsm_dashboard.name"))
        dashboard_object_with_widget = add_widgets_to_fsm_dashboard(dashboard_object, options)
        fsm_dashboard = Dashboard.new(dashboard_object_with_widget.get_dashboard_payload(:db))
        raise "Failed to create fsm dashboard" unless fsm_dashboard.save
      end

      def create_fsm_default_custom_filters
        default_custom_filters_conditions = get_fsm_filter_conditions
        Helpdesk::Filters::CustomTicketFilter.add_default_custom_filters(default_custom_filters_conditions)
        default_custom_filters_conditions.keys.collect { |key|  [key,{ ticket_filter_id: Account.current.ticket_filters.where( name: I18n.t("fsm_dashboard.widgets.#{key}")).first.id }]}.to_h
      end

      def add_widgets_to_fsm_dashboard(dashboard_object, options)
        trends_x_position = 0
        scorecard_x_postion = 0
        picklist_id = ticket_type_picklist_id(SERVICE_TASK_TYPE)
        WIDGETS_NAME_TO_TYPE_MAP.each do |widget_name, type|
          if type == WIDGET_MODULE_TOKEN_BY_NAME[SCORE_CARD]
            position = { x: scorecard_x_postion, y: Y_AXIS_POSITION[:scorecard] }
            dashboard_object.add_widget(type, position, I18n.t("fsm_dashboard.widgets.#{widget_name}"), options[widget_name])
            scorecard_x_postion += SCORECARD_DIMENSIONS[:width]
          else
            position = { x: trends_x_position, y: Y_AXIS_POSITION[:trend] }
            trends_x_position += TREND_DIMENSIONS[:width]
            dashboard_object.add_widget(type, position, I18n.t("fsm_dashboard.widgets.#{widget_name}"), trend_widget_config(picklist_id, TRENDS_WIDGET_TO_METRIC_MAP[widget_name]))
          end
        end
        dashboard_object
      end

      def trend_widget_config(picklist_id, metric_value)
        { group_ids: [::Dashboard::Custom::WidgetConfigValidationMethods::ALL_GROUPS],
          product_id: ::Dashboard::Custom::WidgetConfigValidationMethods::ALL_PRODUCTS,
          ticket_type: picklist_id,
          date_range: ::Dashboard::Custom::WidgetConfigValidationMethods::DATE_FIELDS_MAPPING.key('This month'),
          metric: metric_value }
      end

      def ticket_type_picklist_id(ticket_type)
        pick_list = Account.current.ticket_types_from_cache.find { |x| x.value == ticket_type }
        raise 'Failed to find picklist id for ticket_type ' + ticket_type unless pick_list

        pick_list.id
      end

      def get_fsm_filter_conditions
        start_time = Account.current.custom_date_time_fields_from_cache.find { |x| x.name == TicketFilterConstants::FSM_APPOINTMENT_START_TIME + "_#{Account.current.id}" }
        end_time = Account.current.custom_date_time_fields_from_cache.find { |x| x.name == TicketFilterConstants::FSM_APPOINTMENT_END_TIME + "_#{Account.current.id}" }

        filter_conditions = {
                              FSM_TICKET_FILTERS[0] => {
                                name: I18n.t('fsm_dashboard.widgets.service_tasks_due_today'),
                                filter: [
                                  { 'condition' => "flexifields.#{start_time.column_name}", "operator" => 'is', 'value' => 'today', 'ff_name' => "#{start_time.name}" }
                                ]
                              },

                              FSM_TICKET_FILTERS[1] => {
                                name: I18n.t('fsm_dashboard.widgets.unassigned_service_tasks'),
                                filter: [
                                  { 'condition' => 'responder_id', 'operator' => 'is_in', 'value' => '-1', 'ff_name' => 'default' }
                                ]
                              },

                              FSM_TICKET_FILTERS[2] => {
                                name: I18n.t('fsm_dashboard.widgets.overdue_service_tasks'),
                                filter: [
                                  { 'condition' => "flexifields.#{end_time.column_name}", 'operator' => 'is', 'value' => 'in_the_past', 'ff_name' => "#{end_time.name}" }
                                ]
                              }
                            }
        all_filter_conditions = filter_conditions.each { |k,v| v[:filter] += COMMON_FILTER_CONDITIONS }
        all_filter_conditions
      end

      def cleanup_fsm
        remove_fsm_addon_and_reset_agent_limit
        destroy_field_agent
        destroy_field_group
      rescue StandardError => e
        log_operation_failure('Disable', e)
      end

      def destroy_fsm_dashboard_and_filters
        fsm_dashboard = Account.current.dashboards.find_by_name(I18n.t("fsm_dashboard.name"))
        fsm_dashboard.try(:destroy)
        destroy_fsm_ticket_filters
      end

      def destroy_fsm_ticket_filters
        FSM_TICKET_FILTERS.each do |name|
          Account.current.dashboard_widgets.find_by_name(I18n.t("fsm_dashboard.widgets.#{name}")).try(:destroy)
        end
      end

      def destroy_field_agent
        Agent.destroy_agents(Account.current, AgentType.agent_type_id(FIELD_AGENT))
        AgentType.destroy_agent_type(Account.current, FIELD_AGENT)
      end

      def destroy_field_group
        Group.destroy_groups(Account.current, GroupType.group_type_id(FIELD_GROUP_NAME))
        GroupType.destroy_group_type(Account.current, FIELD_GROUP_NAME)
      end

      def expire_cache
        Account.current.clear_required_ticket_fields_cache
        Account.current.clear_section_parent_fields_cache
        clear_all_section_ticket_fields_cache
      end

      def fsm?
        params[:id] == FSM_FEATURE.to_s
      end

      def reset_field_agent_limit
        Account.current.subscription.reset_field_agent_limit unless Account.current.field_service_management_enabled?
      end

      def remove_fsm_addon_and_reset_agent_limit
        Account.current.subscription.remove_addon(Subscription::Addon::FSM_ADDON)
        reset_field_agent_limit
      end

      def fsm_field_display_name(field_name)
        field_name.gsub('cf_', '')
      end

      def fetch_fsm_fields_to_be_created
        custom_fields_available = Account.current.flexifield_def_entries.map(&:flexifield_alias)
        CUSTOM_FIELDS_TO_RESERVE.select { |x| !custom_fields_available.include?(x[:name] + "_#{Account.current.id}") }
      end
  end
end

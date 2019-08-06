module Admin::AdvancedTicketing::FieldServiceManagement
  module Util
    include Admin::AdvancedTicketing::FieldServiceManagement::Constant
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
        update_field_agent_limit_for_active_account
        create_service_task_field_type
        fsm_fields_to_be_created = fetch_fsm_fields_to_be_created
        reserve_fsm_custom_fields(fsm_fields_to_be_created)
        create_section(fsm_fields_to_be_created)
        create_field_agent_type
        add_data_to_group_type
        create_field_service_manager_role if Account.current.scheduling_fsm_dashboard_enabled?
        expire_cache
      rescue StandardError => e
        log_operation_failure('Enable', e)
      end

      def update_field_agent_limit_for_active_account
        subscription = Account.current.subscription
        return unless subscription.active?

         if subscription.field_agent_limit.nil?
          subscription.field_agent_limit=0
          subscription.save
        end
      end

      def create_field_service_manager_role
        return if Account.current.roles.map(&:name).include?(I18n.t('fsm_scheduling_dashboard.name'))

         role_params = { name: I18n.t('fsm_scheduling_dashboard.name'),
                        description: I18n.t('fsm_scheduling_dashboard.description'),
                        privilege_list: FIELD_SERVICE_MANAGER_ROLE_PRIVILEGES }
        role = Account.current.roles.build(role_params)
        role.save
      end

      def log_operation_failure(operation, exception)
        msg = "#{operation} FSM feature failed"
        error_msg = "#{msg}, account id: #{Account.current.id}, message: #{exception.message}"
        Rails.logger.error error_msg
        NewRelic::Agent.notice_error(exception, description: error_msg)
        msg_param = { account_id: Account.current.id, request_id: Thread.current[:message_uuid], message: exception.message }
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
      def reserve_fsm_custom_fields
        custom_fields_available = Account.current.flexifield_def_entries.map(&:flexifield_alias)
        fields_to_be_created = CUSTOM_FIELDS_TO_RESERVE.select { |x| !custom_fields_available.include?(x[:name] + "_#{Account.current.id}") }
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
        service_task_picklist = Account.current.ticket_fields.find_by_field_type('default_ticket_type').picklist_values.find_by_value('Service Task')
        picklist_id = service_task_picklist.id
        parent_ticket_field_id = service_task_picklist.pickable_id

        # Build Section picklist_mappings
        service_task_section = Account.current.sections.find_by_label(SERVICE_TASK_SECTION)
        section.label = 'Service task section'	        
        unless service_task_section.present?
          service_task_section = Account.current.sections.build
          service_task_section.label = SERVICE_TASK_SECTION
          service_task_section.section_picklist_mappings.build(picklist_value_id: picklist_id)
        end
        # Build Section fields
        section_fields = []
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
      
      def add_data_to_group_type
        group_type = GroupType.create_group_type(Account.current, FIELD_GROUP_NAME)
        raise "Field group type did not get created" unless group_type
      end

      def create_field_agent_type
        agent_type = AgentType.create_agent_type(Account.current, FIELD_AGENT)
        raise "Field agent type did not get created" unless agent_type
      end

      def cleanup_fsm
        remove_fsm_addon_and_reset_agent_limit
        destroy_field_agent
        destroy_field_group
      rescue StandardError => e
        log_operation_failure('Disable', e)
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

      def fetch_already_available_fields
        custom_fields_available = Account.current.flexifield_def_entries.map(&:flexifield_alias)
        fields_to_be_created = CUSTOM_FIELDS_TO_RESERVE.select { |x| !custom_fields_available.include?(x[:name] + "_#{Account.current.id}") }
        fields_to_be_created
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

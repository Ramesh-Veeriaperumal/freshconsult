module Admin::AdvancedTicketing::FieldServiceManagement
  module Util
    include Admin::AdvancedTicketing::FieldServiceManagement::Constant
    include Dashboard::Custom::CustomDashboardConstants
    include Helpdesk::Ticketfields::ControllerMethods
    include Cache::Memcache::Helpdesk::Section
    include GroupConstants
    include SubscriptionsHelper

    def notify_fsm_dev(subject, message)
      message ||= {}
      message[:environment] = Rails.env
      topic = SNS['field_service_management']
      DevNotification.publish(topic, subject, message.to_json) unless Rails.env.development? || Rails.env.test?
    end

    private

      def perform_fsm_operations(enable_options = {})
        Rails.logger.info "Started adding FSM artifacts for Account - #{Account.current.id}"
        @fsm_signup_flow = enable_options[:fsm_signup_flow].presence || false
        add_required_features_for_lower_plans
        create_field_tech_role
        update_field_agent_limit_for_active_account
        create_field_agent_type
        create_field_group_type
        create_field_service_manager_role
        create_service_task_field_type
        fsm_fields_to_be_created = fetch_fsm_fields_to_be_created
        reserve_fsm_custom_fields(fsm_fields_to_be_created)
        create_fsm_section
        create_fsm_dashboard
        enable_fsm_default_settings
        generate_fsm_seed_data
        expire_cache
        Rails.logger.info "Completed adding FSM artifacts for Account - #{Account.current.id}"
      rescue StandardError => e
        log_operation_failure('Enable', e)
      end

      def update_field_agent_limit_for_active_account
        subscription = Account.current.subscription
        return unless subscription.active?

        if subscription.field_agent_limit.nil?
          additional_info = subscription.additional_info
          additional_info[:field_agent_limit] = 0
          # rubocop:disable SkipsModelValidations
          subscription.update_column(:additional_info, additional_info.to_yaml)
          # rubocop:enable SkipsModelValidations
        end
      end

      def create_field_tech_role
        field_tech_role = Helpdesk::Roles::FIELD_TECHNICIAN_ROLE
        return if Account.current.roles.map(&:name).include?(field_tech_role[:name])

        role_params = {
          name: field_tech_role[:name],
          description: field_tech_role[:description],
          default_role: true,
          privilege_list: field_tech_role[:privileges],
          agent_type: AgentType.agent_type_id(:field_agent)
        }
        role = Account.current.roles.build(role_params)
        role.save!
      end

      def create_field_service_manager_role
        return if Account.current.roles.map(&:name).include?(I18n.t('fsm_scheduling_dashboard.name')) || !Account.current.has_feature?(:custom_roles)

        role_params = {
          name: I18n.t('fsm_scheduling_dashboard.name'),
          description: I18n.t('fsm_scheduling_dashboard.description'),
          privilege_list: FIELD_SERVICE_MANAGER_ROLE_PRIVILEGES,
          agent_type: AgentType.agent_type_id(:support_agent)
        }
        role = Account.current.roles.build(role_params)
        role.save!
      end

      def log_operation_failure(operation, exception)
        msg = "#{operation} FSM feature failed in #{Rails.env}"
        error_msg = "#{msg}, account id: #{Account.current.id}, message: #{exception.message}"
        Rails.logger.error "#{error_msg} backtrace: #{exception.backtrace.join("\n")}"
        NewRelic::Agent.notice_error(exception, description: error_msg)
        msg_param = { account_id: Account.current.id, request_id: Thread.current[:message_uuid], message: exception.message }
        sns_subject = "[#{operation}][FSM][exception][#{Rails.env}] #{exception.message}"
        notify_fsm_dev(sns_subject, msg_param)
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
          field_options: { section_present: true }.with_indifferent_access
        }

        raise "Couldn't create a new ticket type for service task" unless type_field.update_attributes(type_field_options)
      end

      # Reserve the required FSM custom fields. refer: CUSTOM_FIELDS_TO_RESERVE
      def reserve_fsm_custom_fields(fields_to_be_created)
        last_occupied_position = ticket_fields.count + 1
        fields_to_be_created.each_with_index do |custom_field, index|
          payload = custom_field_generator(custom_field.merge(position: last_occupied_position + index))
          create_fsm_field(payload, Account.current)
        end
      end

      def create_fsm_field(field_details, account)
        field_name = field_details.delete(:name)
        Rails.logger.info("Creating FSM field #{field_name} for Account - #{Account.current.id} ")
        field_options = { alias_present: true, signup_flow: @fsm_signup_flow }
        ff_def_entry = FlexifieldDefEntry.new ff_meta_data(field_details, account, field_options)
        Rails.logger.info("Flexifield data for #{field_name} :: #{ff_def_entry}")
        field_details.merge!(flexifield_def_entry_details(ff_def_entry))

        ticket_field = ticket_fields.build(field_details)
        ticket_field.name = field_name
        ticket_field.flexifield_def_entry = ff_def_entry

        ticket_field.save!
        Rails.logger.info("FSM field #{field_name} created")
        ticket_field.insert_at(field_details[:position]) if field_details[:position].present?
      end

      def ticket_fields
        @ticket_fields ||= Account.current.ticket_fields_including_nested_fields
      end

      def custom_field_generator(options)
        {
          type: options[:type],
          label: options[:label],
          field_type: options[:field_type],
          position: options[:position],
          name: "#{options[:name]}_#{Account.current.id}",
          label_in_portal: options[:label_in_portal],
          field_options: { section: true, fsm: true }.with_indifferent_access,
          description: '',
          active: true,
          required: options[:required] || false,
          required_for_closure: false,
          visible_in_portal: false,
          editable_in_portal: false,
          required_in_portal: false,
          flexifield_alias: options[:flexifield_alias]
        }
      end

      # create a dynamic section named "Service Task" and attach the reserved custom fields to them.
      def create_fsm_section
        Rails.logger.info("Processing fsm section operations for Account - #{Account.current.id}")
        # TODO: check for section limit.
        ticket_type_field = Account.current.ticket_fields_with_nested_fields.find_by_field_type('default_ticket_type')
        unless ticket_type_field.field_options['section_present']
          ticket_type_field.field_options['section_present'] = true
          ticket_type_field.save!
        end

        # Build Section picklist_mappings
        service_task_picklist = ticket_type_field.picklist_values.find_by_value(SERVICE_TASK_TYPE)
        picklist_id = service_task_picklist.id
        parent_ticket_field_id = service_task_picklist.pickable_id
        service_task_section = Account.current.sections.find_by_label(SERVICE_TASK_SECTION)
        if service_task_section.blank?
          service_task_section = ticket_type_field.sections.build
          service_task_section.label = SERVICE_TASK_SECTION
          service_task_section.ticket_field_id = ticket_type_field.id
          service_task_section.options = { 'fsm' => true }.with_indifferent_access
          service_task_section.section_picklist_mappings.build(picklist_value_id: picklist_id, picklist_id: service_task_picklist.picklist_id)
        else
          service_task_section.ticket_field_id = ticket_type_field.id
          service_task_section.options = service_task_section.options.with_indifferent_access
          service_task_section.options['fsm'] = true
        end

        # Build Section fields
        fields_to_be_created = fsm_custom_field_to_reserve
        section_fields_ticket_field_ids = service_task_section.section_fields.map(&:ticket_field_id)
        fields_to_be_created.each_with_index do |custom_field, index|
          field_data = Account.current.ticket_fields_with_archived_fields_only.where(name: "#{custom_field[:name]}_#{Account.current.id}").first
          unless section_fields_ticket_field_ids.include?(field_data.id)
            section_field = { parent_ticket_field_id: parent_ticket_field_id, ticket_field_id: field_data.id, position: index + 1 }
            service_task_section.section_fields.build(section_field)
          end
          is_archived_field = Account.current.archive_ticket_fields_enabled? && field_data.deleted
          is_valid_fsm_field = field_data.field_options[:section] && field_data.field_options[:fsm]
          next if is_valid_fsm_field && !is_archived_field

          unless is_valid_fsm_field
            field_data.field_options = field_data.field_options.with_indifferent_access
            field_data.field_options[:section] = true
            field_data.field_options[:fsm] = true
          end
          field_data.deleted = false if is_archived_field
          field_data.save!
        end
        service_task_section.save!
      end

      def create_field_group_type
        if Account.current.group_types.find_by_name(FIELD_GROUP_NAME).nil?
          group_type = GroupType.create_group_type(Account.current, FIELD_GROUP_NAME)
          raise 'Field group type did not get created' unless group_type
        end
      end

      def create_field_agent_type
        if Account.current.agent_types.find_by_name(FIELD_AGENT).nil?
          agent_type = AgentType.create_agent_type(Account.current, FIELD_AGENT)
          raise 'Field agent type did not get created' unless agent_type
        end
      end

      def create_fsm_dashboard
        return unless Account.current.has_feature?(:custom_dashboard)

        dashboard_object = DashboardObjectConcern.new(I18n.t("fsm_dashboard.name"))
        dashboard_object_with_widget = add_widgets_to_fsm_dashboard(dashboard_object)
        fsm_dashboard = Dashboard.new(dashboard_object_with_widget.get_dashboard_payload(:db))
        fsm_dashboard.save!
      end

      def add_widgets_to_fsm_dashboard(dashboard_object)
        trends_x_position = 0
        scorecard_x_postion = 0
        picklist_id = ticket_type_picklist_id(SERVICE_TASK_TYPE)
        WIDGETS_NAME_TO_TYPE_MAP.each do |widget_name, type|
          if type == WIDGET_MODULE_TOKEN_BY_NAME[SCORE_CARD]
            position = { x: scorecard_x_postion, y: Y_AXIS_POSITION[:scorecard] }
            dashboard_object.add_widget(type, position, I18n.t("fsm_dashboard.widgets.#{widget_name}"), ticket_filter_id: widget_name)
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


      def cleanup_fsm
        Rails.logger.info "Started disabling FSM feature for Account - #{Account.current.id}"
        remove_fsm_addon_and_reset_agent_limit
        destroy_field_tech_role
        destroy_field_agent
        destroy_field_group
        destroy_customer_signature
        disable_fsm_settings
        handle_service_task_automations
        Rails.logger.info "Completed disabling FSM feature for Account - #{Account.current.id}"
      rescue StandardError => e
        log_operation_failure('Disable', e)
      end

      def destroy_fsm_dashboard_and_filters
        fsm_dashboard = Account.current.dashboards.find_by_name(I18n.t('fsm_dashboard.name'))
        fsm_dashboard.try(:destroy)
        destroy_fsm_ticket_filters
      end

      def destroy_field_tech_role
        role = Account.current.roles.find_by_name(Helpdesk::Roles::FIELD_TECHNICIAN_ROLE[:name])
        role.try(:destroy)
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

      def destroy_customer_signature
        Account.current.ticket_fields.where(name: CUSTOMER_SIGNATURE + "_#{Account.current.id}").destroy_all
      end

      def handle_service_task_automations
        fsm_supported_plan?(Account.current.subscription.subscription_plan) ? disable_service_task_automation_rules : destroy_service_task_automation_rules
      end

      def destroy_service_task_automation_rules
        Account.current.all_service_task_dispatcher_rules.find_each(&:destroy)
        Account.current.all_service_task_observer_rules.find_each(&:destroy)
        Account.current.reload
      end

      def disable_service_task_automation_rules
        Account.current.service_task_dispatcher_rules.each(&:disable)
        Account.current.service_task_observer_rules.each(&:disable)
        Account.current.reload
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
        fsm_fields_to_be_created = fsm_custom_field_to_reserve.reject { |x| custom_fields_available.include?(x[:name] + "_#{Account.current.id}") }
        Rails.logger.info "FSM fields to be created for Account - #{Account.current.id} :: #{fsm_fields_to_be_created.inspect}"
        fsm_fields_to_be_created
      end

      def fsm_appointment_start_time_ff_column_name
        start_time = Account.current.custom_date_time_fields_from_cache.find { |x| x.name == TicketFilterConstants::FSM_APPOINTMENT_START_TIME + "_#{Account.current.id}" }
        start_time.column_name
      end

      def fsm_custom_fields_to_validate
        fsm_section = Account.current.sections.preload(:section_fields).find_by_label(SERVICE_TASK_SECTION)
        return [] if fsm_section.blank?

        fsm_field_ids = fsm_section.section_fields.map(&:ticket_field_id)
        fsm_fields_to_validate = TicketsValidationHelper.custom_non_dropdown_fields(self).select { |x| fsm_field_ids.include?(x.id) }
        fsm_fields_to_validate
      end

      def fsm_custom_field_to_reserve
        FSM_DEFAULT_TICKET_FIELDS
      end

      def generate_fsm_seed_data
        return unless @fsm_signup_flow

        ENV['FIXTURE_PATH'] = 'db/fixtures/fsm'
        SeedFu::PopulateSeed.populate
      end

      def add_required_features_for_lower_plans
        Account.current.add_feature(:dynamic_sections) unless Account.current.has_feature?(:dynamic_sections)
      end

      def enable_fsm_default_settings
        return unless AccountSettings::SettingToSettingsMapping.include?(:field_service_management)

        fsm_settings_to_add = AccountSettings::SettingToSettingsMapping[:field_service_management].select { |setting| AccountSettings::SettingsConfig[setting][:default] }
        Rails.logger.debug("Adding FSM default settings for account - #{Account.current.id} :: #{fsm_settings_to_add.inspect}")
        fsm_settings_to_add.each { |setting| Account.current.set_setting(setting) }
        Account.current.save!
      end

      def disable_fsm_settings
        return unless AccountSettings::SettingToSettingsMapping.include?(:field_service_management)

        fsm_settings_to_reset = AccountSettings::SettingToSettingsMapping[:field_service_management].select { |setting| !FSM_SETTINGS_TO_RETAIN_STATE.include?(setting) && Account.current.has_feature?(setting) }
        Rails.logger.debug("Resetting FSM settings for account - #{Account.current.id} :: #{fsm_settings_to_reset.inspect}")
        fsm_settings_to_reset.each { |setting| Account.current.reset_feature(setting) }
        Account.current.save!
      end
  end
end

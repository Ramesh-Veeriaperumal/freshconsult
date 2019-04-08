module Admin::AdvancedTicketing::FieldServiceManagement
  module Util
    include Admin::AdvancedTicketing::FieldServiceManagement::Constant
    include Helpdesk::Ticketfields::ControllerMethods
    include Cache::Memcache::Helpdesk::Section
    include GroupConstants

    private

      def perform_fsm_operations
        create_service_task_field_type
        reserve_fsm_custom_fields
        create_section
        create_field_agent_type
        add_data_to_group_type
        expire_cache
      rescue StandardError => e
        cleanup_fsm
        Rails.logger.error "error in performing fsm operations, account id: #{Account.current.id}, message: #{e.message}"
        render_request_error(:something_wrong_in_fsm_enable, 500)
      end

      def feature_fsm?
        cname_params[:name].to_sym == FSM_FEATURE
      end

      def create_service_task_field_type
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
        last_occupied_position = ticket_fields.count + 1
        CUSTOM_FIELDS_TO_RESERVE.each_with_index do |custom_field, index|
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
      def create_section
        # TODO: check for section limit.
        service_task_picklist = Account.current.ticket_fields.find_by_field_type('default_ticket_type').picklist_values.find_by_value('Service Task')
        picklist_id = service_task_picklist.id
        parent_ticket_field_id = service_task_picklist.pickable_id

        # Build Section picklist_mappings
        section = Account.current.sections.build
        section.label = 'Service task section'
        section.section_picklist_mappings.build(picklist_value_id: picklist_id)

        # Build Section fields
        section_fields = []
        CUSTOM_FIELDS_TO_RESERVE.each_with_index do |custom_field, index|
          field = Account.current.ticket_fields.find_by_name("#{custom_field[:name]}_#{Account.current.id}")
          section_fields << { parent_ticket_field_id: parent_ticket_field_id, ticket_field_id: field.id, position: index + 1 }
        end

        section_fields.each do |section_field|
          section.section_fields.build(section_field)
        end

        section.save
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
        destroy_custom_fields
        destroy_sections
        destroy_service_ticket_type
        destroy_field_agent
        destroy_field_group
      end

      def destroy_custom_fields
        CUSTOM_FIELDS_TO_RESERVE.each do |custom_field|
          name = "#{custom_field[:name]}_#{Account.current.id}"
          field = Account.current.ticket_fields.find_by_name(name)
          field.destroy if field.present?
        end
      end

      def destroy_sections
        Account.current.picklist_values.find_by_value(SERVICE_TASK_TYPE).try(:section).try(:destroy)
      end

      def destroy_service_ticket_type
        type_field = Account.current.ticket_fields.preload(:picklist_values => :section).find_by_field_type('default_ticket_type')
        return unless type_field.present?
        picklist_values = type_field.picklist_values

        new_picklist_values = picklist_values.reject {|picklist| picklist[:value] === SERVICE_TASK_TYPE}
        service_task_type = picklist_values.find_by_value(SERVICE_TASK_TYPE)
        service_task_type.destroy if service_task_type.present? && new_picklist_values.size > 0

        field_options = type_field[:field_options] || {}
        section_present_in_other_picklists = new_picklist_values.any? {|picklist| picklist.section.present?}

        if !section_present_in_other_picklists && field_options[:section_present].present?
          field_options.delete(:section_present)
          type_field.update_attributes({field_options: field_options})
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
  end
end
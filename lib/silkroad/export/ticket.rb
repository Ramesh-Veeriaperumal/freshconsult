module Silkroad
  module Export
    class Ticket < Base
      include Silkroad::Constants::Ticket

      def build_filter_conditions(export_params)
        filter_conditions = export_params[:data_hash].map do |filter_param|
          condition = {}
          condition[:column_name] = filter_param[:condition]
          condition[:operator] = OPERATOR_MAPPING[filter_param[:operator].to_sym]
          condition[:operand] = filter_param[:value].is_a?(String) ? filter_param[:value].split(',') : Array(filter_param[:value])
          condition[:operand] = condition[:operand].map { |operand| OPERAND_MAPPING.key?(operand) ? OPERAND_MAPPING[operand] : operand }
          method_name = "transform_#{modify_column_name(condition[:column_name])}_params"
          condition = safe_send(method_name, condition) if respond_to?(method_name, true)
          condition[:operand].flatten! if condition.present? && !condition[:operator].in?(NESTED_OPERATORS)
          condition.presence
        end.flatten.compact
        add_ticket_state_filter_related_conditions(filter_conditions, export_params)
        add_frDueBy_related_conditions(filter_conditions)
        add_dueby_related_conditions(filter_conditions)
        allow_only_permissible_tickets(filter_conditions)
        handle_empty_conditions(filter_conditions)
        filter_conditions
      end

      private

        def data_export_type
          account.launched?(:silkroad_export) ? DataExport::EXPORT_TYPE[:ticket] : DataExport::EXPORT_TYPE[:ticket_shadow]
        end

        def export_name
          EXPORT_NAME
        end

        def construct_date_range_condition(export_params)
          {
            from: Time.parse(export_params[:start_date]).iso8601,
            to: Time.parse(export_params[:end_date]).iso8601,
            column_name: export_params[:ticket_state_filter]
          }
        end

        def modify_column_name(column_name)
          column_name.split('.').join('_')
        end

        def transform_helpdesk_tags_name_params(condition)
          condition[:column_name] = TICKET_FIELDS_COLUMN_NAME_MAPPING[:ticket_tags]
          condition[:operand] = account.tags.where(name: condition[:operand]).pluck(:id)
          condition
        end

        def transform_due_by_params(condition)
          # This is for local testing purposes. Will comment out this method until we decide and implement in Silkroad
          minimum_required_condition = (condition[:operand].map!(&:to_i) - TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN.slice(:all_due, :due_today, :due_tomo).values).min
          operands = minimum_required_condition ? condition[:operand].select { |operand| operand <= minimum_required_condition } : condition[:operand]
          transformed_operands = operands.map do |operand|
            case operand
            when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:all_due]
              # condition[:operator] = OPERATORS[:between]
              [START_DATE..Time.zone.now]
            when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_today]
              # condition[:operator] = OPERATORS[:between]
              [Time.zone.now.beginning_of_day..Time.zone.now.end_of_day]
            when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_tomo]
              # condition[:operator] = OPERATORS[:between]
              [Time.zone.now.tomorrow.beginning_of_day..Time.zone.now.tomorrow.end_of_day]
            when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_eight]
              # condition[:operator] = OPERATORS[:between]
              [Time.zone.now..8.hours.from_now]
            when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_four]
              # condition[:operator] = OPERATORS[:between]
              [Time.zone.now..4.hours.from_now]
            when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_two]
              # condition[:operator] = OPERATORS[:between]
              [Time.zone.now..2.hours.from_now]
            when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_hour]
              # condition[:operator] = OPERATORS[:between]
              [Time.zone.now..1.hour.from_now]
            when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_half_hour]
              # condition[:operator] = OPERATORS[:between]
              [Time.zone.now..30.minutes.from_now]
            else
              []
            end
          end
          transformed_operands = transformed_operands.flatten.rangify
          operand = transformed_operands.first
          conditions_after_merge = if operand.begin == START_DATE
            construct_filter_condition(condition[:column_name], OPERATORS[:less_than], [operand.end.iso8601])
          else
            if transformed_operands.length == 1
              construct_filter_condition(condition[:column_name], OPERATORS[:between], [operand.begin.iso8601, operand.end.iso8601])
            else
              nested_conditions = transformed_operands.map do |transformed_operand|
                construct_filter_condition(condition[:column_name], OPERATORS[:between], [transformed_operand.begin.iso8601, transformed_operand.end.iso8601])
              end
              construct_nested_condition('nested_or', nested_conditions)
            end
          end
          conditions_after_merge
        end
        alias transform_frDueBy_params transform_due_by_params
        alias transform_nr_due_by_params transform_due_by_params

        def transform_created_at_params(condition)
          operand = condition[:operand].first
          if operand.include?(' - ')
            from, to = operand.split(' - ')
            start_date = Time.zone.parse(from).utc.iso8601
            end_date = Time.zone.parse(to).utc.iso8601
            condition[:operator] = OPERATORS[:between]
            condition[:operand]  = [start_date, end_date]
          elsif operand.to_i != 0
            condition[:operator] = OPERATORS[:greater_than]
            condition[:operand]  = [Time.zone.now.ago(operand.to_i.minutes).iso8601]
          else
            case operand
            when 'today'
              condition[:operator] = OPERATORS[:greater_than]
              condition[:operand]  = [Time.zone.now.beginning_of_day.iso8601]
            when 'yesterday'
              condition[:operator] = OPERATORS[:between]
              condition[:operand]  = [Time.zone.now.yesterday.beginning_of_day.iso8601, Time.zone.now.beginning_of_day.iso8601]
            when 'week'
              condition[:operator] = OPERATORS[:greater_than]
              condition[:operand]  = [Time.zone.now.beginning_of_week.iso8601]
            when 'last_week'
              condition[:operator] = OPERATORS[:greater_than]
              condition[:operand]  = [Time.zone.now.beginning_of_day.ago(7.days).iso8601]
            when 'month'
              condition[:operator] = OPERATORS[:greater_than]
              condition[:operand]  = [Time.zone.now.beginning_of_month.iso8601]
            when 'last_month'
              condition[:operator] = OPERATORS[:greater_than]
              condition[:operand]  = [Time.zone.now.beginning_of_day.ago(1.month).iso8601]
            when 'two_months'
              condition[:operator] = OPERATORS[:greater_than]
              condition[:operand]  = [Time.zone.now.beginning_of_day.ago(2.months).iso8601]
            when 'six_months'
              condition[:operator] = OPERATORS[:greater_than]
              condition[:operand]  = [Time.zone.now.beginning_of_day.ago(6.months).iso8601]
            end
          end
          condition
        end

        def transform_status_params(condition)
          condition[:operand].map! { |operand| operand.in?(0, '0') ? Helpdesk::TicketStatus.unresolved_statuses(account) : operand.to_i }
          condition
        end

        def transform_agent_params(condition)
          condition[:operand].map! { |operand| operand.nil? ? nil : operand.in?(0, '0') ? user.id : operand.to_i }
          condition[:operand] = [user.id] if user_permission == 'assigned_tickets'
          if condition[:column_name] == 'any_agent_id'
            nested_conditions = [construct_filter_condition('responder_id', condition[:operator], condition[:operand]),
                                 construct_filter_condition('internal_agent_id', condition[:operator], condition[:operand])]
            condition = construct_nested_condition('nested_or', nested_conditions)
          end
          condition
        end
        alias transform_any_agent_id_params transform_agent_params
        alias transform_internal_agent_id_params transform_agent_params
        alias transform_responder_id_params transform_agent_params

        def transform_group_params(condition)
          return nil if user_permission == 'assigned_tickets'

          condition[:operand].map! { |operand| operand.nil? ? nil : operand.in?(0, '0') ? user_groups : operand.to_i }
          condition[:operand] = condition[:operand] & user_groups if user_permission == 'group_tickets'

          if condition[:column_name] == 'any_group_id'
            nested_conditions = [construct_filter_condition('group_id', condition[:operator], condition[:operand]),
                                 construct_filter_condition('internal_group_id', condition[:operator], condition[:operand])]
            condition = construct_nested_condition('nested_or', nested_conditions)
          end
          condition
        end
        alias transform_any_group_id_params transform_group_params
        alias transform_internal_group_id_params transform_group_params
        alias transform_group_id_params transform_group_params

        def add_ticket_state_filter_related_conditions(filter_conditions, export_params)
          default_status_condition = case export_params[:ticket_state_filter]
          when 'resolved_at'
            [Helpdesk::Ticketfields::TicketStatus::RESOLVED, Helpdesk::Ticketfields::TicketStatus::CLOSED]
          when 'closed_at'
            [Helpdesk::Ticketfields::TicketStatus::CLOSED]
          else
            []
          end
          return if default_status_condition.blank?

          if (index = filter_conditions.index { |condition| condition[:column_name] == 'status' })
            filter_conditions[index][:operand] &= default_status_condition
          else
            condition = construct_filter_condition('status', OPERATORS[:in], default_status_condition)
            filter_conditions.push(condition)
          end
        end

        def add_frDueBy_related_conditions(filter_conditions)
          if column_present_in_filter_conditions?(filter_conditions, ['frDueBy'])
            filter_conditions.push(AGENT_RESPONDED_AT_NULL_CONDITION)

            if (index = filter_conditions.index { |condition| condition[:column_name] == 'source' })
              filter_conditions[index][:operand].push(TicketConstants::SOURCE_KEYS_BY_TOKEN[:outbound_email]).uniq!
            else
              filter_conditions.push(SOURCE_NOT_OUTBOUND_EMAIL_CONDITION)
            end
          end
        end

        def add_dueby_related_conditions(filter_conditions)
          if column_present_in_filter_conditions?(filter_conditions, DUE_BY_CONDITIONS)
            sla_timer_on_statuses = Helpdesk::TicketStatus.donot_stop_sla_statuses(account)
            if (index = filter_conditions.index { |condition| condition[:column_name] == 'status' })
              filter_conditions[index][:operand] &= sla_timer_on_statuses
            else
              condition = construct_filter_condition('status', OPERATORS[:in], sla_timer_on_statuses)
              filter_conditions.push(condition)
            end
          end
        end

        def allow_only_permissible_tickets(filter_conditions)
          case user_permission

          when 'group_tickets'
            unless column_present_in_filter_conditions?(filter_conditions, GROUP_COLUMNS)
              nested_conditions = [construct_filter_condition('group_id', OPERATORS[:in], user_groups),
                                   construct_filter_condition('responder_id', OPERATORS[:in], [user.id])]
              if account.shared_ownership_enabled?
                nested_conditions << construct_filter_condition('internal_group_id', OPERATORS[:in], user_groups)
                nested_conditions << construct_filter_condition('internal_agent_id', OPERATORS[:in], [user.id])
              end
              filter_conditions.push(construct_nested_condition('nested_or', nested_conditions))
            end

          when 'assigned_tickets'
            unless column_present_in_filter_conditions?(filter_conditions, AGENT_COLUMNS)
              nested_conditions = [construct_filter_condition('responder_id', OPERATORS[:in], [user.id])]
              nested_conditions << construct_filter_condition('internal_agent_id', OPERATORS[:in], [user.id]) if account.shared_ownership_enabled?
              filter_conditions.push(construct_nested_condition('nested_or', nested_conditions))
            end
          end
          filter_conditions
        end

        def column_present_in_filter_conditions?(filter_conditions, column_names)
          return true if filter_conditions.find { |condition| condition[:column_name].in?(column_names) }

          filter_conditions.any? do |filter_condition|
            filter_condition[:operator].in?(NESTED_OPERATORS) && column_present_in_filter_conditions?(filter_condition[:nested_conditions], column_names)
          end
        end

        def handle_empty_conditions(filter_conditions)
          # Ignore such requests directly from here?
          filter_conditions.each do |condition|
            condition[:operand] = [nil] if condition[:operand].blank? && !NESTED_OPERATORS.include?(condition[:operator])
          end
        end

        def user_permission
          @user_permission ||= user.agent.ticket_permission_token.to_s
        end

        def user_groups
          @user_groups ||= user.agent_groups.pluck(:group_id)
        end

        ### FILTER CONDITIONS PART ENDS HERE ###

        ### EXPORT FIELDS PART STARTS HERE ###

        def export_fields(export_params)
          transform_ticket_fields_hash(export_params[:ticket_fields])
            .merge(transform_contact_fields_hash(export_params[:contact_fields]))
            .merge(transform_company_fields_hash(export_params[:company_fields]))
        end

        def transform_ticket_fields_hash(fields)
          # exclude encrypted fields
          fields.delete_if { |key, value| key.to_s.match(/^cf_enc/) }

          fields.to_h.each_with_object({}) do |(column, display_name), custom_fields_hash|
            transformed_column_name = TICKET_FIELDS_COLUMN_NAME_MAPPING[column] || ticket_custom_fields_mapping(column) || column.to_s
            custom_fields_hash[transformed_column_name] = display_name
          end
        end

        def ticket_custom_fields_mapping(column)
          unless defined?(@ticket_custom_fields_mapping)
            # Compute table_name when we handle ticket_field_data
            table_name = FLEXIFIELDS
            @ticket_custom_fields_mapping = account.ticket_fields_from_cache.each_with_object({}) do |custom_field, map|
              map[custom_field.name.to_sym] = "#{table_name}.#{custom_field.column_name}"
            end
          end
          @ticket_custom_fields_mapping[column]
        end

        def transform_contact_fields_hash(fields)
          fields.to_h.each_with_object({}) do |(column, display_name), custom_fields_hash|
            transformed_column_name = CONTACT_FIELDS_COLUMN_NAME_MAPPING[column] || contact_custom_fields_mapping(column) || column.to_s
            custom_fields_hash[transformed_column_name] = display_name
          end
        end

        def contact_custom_fields_mapping(column)
          unless defined?(@contact_custom_fields_mapping)
            table_name = CONTACT_FIELD_DATA
            @contact_custom_fields_mapping = account.contact_form.custom_fields_cache.each_with_object({}) do |custom_field, map|
              map[custom_field.name.to_sym] = "#{table_name}.#{custom_field.column_name}"
            end
          end
          @contact_custom_fields_mapping[column]
        end

        def transform_company_fields_hash(fields)
          fields.to_h.each_with_object({}) do |(column, display_name), custom_fields_hash|
            transformed_column_name = COMPANY_FIELDS_COLUMN_NAME_MAPPING[column] || company_custom_fields_mapping(column) || column.to_s
            custom_fields_hash[transformed_column_name] = display_name
          end
        end

        def company_custom_fields_mapping(column)
          unless defined?(@company_custom_fields_mapping)
            table_name = COMPANY_FIELD_DATA
            @company_custom_fields_mapping = account.company_form.custom_fields_cache.each_with_object({}) do |custom_field, map|
              map[custom_field.name.to_sym] = "#{table_name}.#{custom_field.column_name}"
            end
          end
          @company_custom_fields_mapping[column]
        end

        ### EXPORT FIELDS PART ENDS HERE ###

        def get_output_format(export_params)
          FORMAT_MAPPING[export_params[:format].to_sym]
        end

        def construct_additional_info(_export_params)
          {
            timezone: Time.zone.tzinfo.name,
            features: {
              survey: SURVEY_FEATURE_MAPPING[account.new_survey_enabled?.to_s.to_sym]
            },
            text: {
            }
          }
        end
    end
  end
end

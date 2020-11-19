# frozen_string_literal: true

module Admin
  class GroupValidation < ::PrivateApiGroupValidation
    include GroupConstants
    include Admin::TicketFieldsErrorHelper

    attr_accessor(*AUTOMATIC_AGENT_ASSIGNMENT_PARAMS | %i[automatic_agent_assignment business_calendar_id])

    validates :business_calendar_id, data_type: { rules: Integer, required: false }, if: -> { business_calendar_id.present? }
    validates :automatic_agent_assignment, data_type: { rules: Hash }, if: -> { @automatic_agent_assignment }
    validates :enabled, data_type: { rules: 'Boolean', required: true }, custom_inclusion: { in: [true, false] }, allow_nil: false, if: -> { @automatic_agent_assignment }
    validates :type, required: true, if: -> { @enabled }
    validates :settings, data_type: { rules: Array, required: true }, if: -> { @enabled && @automatic_agent_assignment && channel_specific? }
    validates :settings, custom_absence: { message: :invalid_field }, if: -> { @automatic_agent_assignment && omni_channel? }

    # type field is getting override in error_options due to group_type -> type, that's why custom error
    validate :validate_type_field, if: -> { errors.blank? && @automatic_agent_assignment }
    validate :validate_settings, if: -> { errors.blank? && @enabled && @settings }
    validate :validate_ticket_lbrr_settings, if: -> { errors.blank? && @enabled && @settings && Account.current.lbrr_by_omniroute_enabled? }

    def initialize(request_params, item = nil, _allow_string_param = nil, _model_decorator = nil)
      instance_variable_set('@automatic_agent_assignment', request_params[:automatic_agent_assignment])
      if @automatic_agent_assignment&.is_a?(Hash)
        AUTOMATIC_AGENT_ASSIGNMENT_PARAMS.each do |field|
          instance_variable_set("@#{field}", @automatic_agent_assignment[field]) if @automatic_agent_assignment.key?(field)
        end
      end
      safe_send('group_type=', request_params[:type])
      safe_send('business_calendar_id=', request_params[:business_calendar_id])
      super(request_params, item)
    end

    private

      def validate_type_field
        field_name = 'automatic_agent_assignment[:type]'.to_sym
        missing_field_error(field_name) if @enabled && @automatic_agent_assignment[:type].nil?
        expected = Account.current.omni_bundle_account? ? CHANNEL_SPECIFIC.map(&:to_i) : AUTOMATIC_AGENT_ASSIGNMENT_TYPES
        not_included_error(field_name, expected.join(', ')) if @automatic_agent_assignment[:type] && !expected.include?(@type)
      end

      def validate_settings
        invalid_field_error(:settings) and return unless channel_specific? # validates :settings not working

        validate_channel_field(grouped_settings.keys.map(&:to_s)) and return if grouped_settings

        channel_name = Account.current.omni_groups? ? OMNI_GROUP_CHANNEL_NAMES.values : CHANNEL_NAMES.values
        channel_name.map(&:to_sym).each do |channel|
          channel_settings = grouped_settings[channel]
          next if channel_settings.blank? || !validate_unique_channel_settings(channel, channel_settings)

          setting = channel_settings.first
          (AUTOMATIC_AGENT_ASSIGNMENT_SETTINGS_PARAMS - %i[channel]).each do |param|
            safe_send("validate_#{param}_field", setting, channel)
            return if errors.present?
          end
        end
      end

      def validate_channel_field(channels)
        expected = Account.current.omni_groups? ? OMNI_GROUP_CHANNEL_NAMES.values : CHANNEL_NAMES.values
        field_name = 'automatic_agent_assignment[:settings][:channel]'.to_sym
        not_included_error(field_name, expected.join(', ')) unless channels & expected == channels
      end

      def validate_assignment_type_field(setting, channel_name)
        assignment_type = setting[:assignment_type]
        if assignment_type.to_s.present?
          expected = Account.current.omni_groups? ? OMNI_GROUP_ASSIGNMENT_TYPE[channel_name] : ASSIGNMENT_TYPE_MAPPINGS.values
          field_name = 'channel_assignment_type'.to_sym
          not_included_error(field_name, expected.join(', ')) unless expected.include?(assignment_type)
        else
          field_name = 'automatic_agent_assignment[:settings][:assignment_type]'.to_sym
          missing_field_error(field_name)
        end
      end

      def validate_assignment_type_settings_field(setting, channel_name)
        assignment_type_settings = setting[:assignment_type_settings]
        if channel_name == CHANNEL_NAMES[:freshdesk].to_sym
          # capping_limit range not validating in base validations
          valid_capping_limit?(setting)
        elsif Account.current.omni_groups? && channel_name == OMNI_GROUP_CHANNEL_NAMES[:freshchat].to_sym
          field_name = assignment_type_settings.blank? ? 'automatic_agent_assignment[:settings][:assignment_type_settings]'.to_sym : 'automatic_agent_assignment[:settings][:assignment_type_settings][:reassign_conversation_of_inactive_agent]'.to_sym
          reassign_conversation_of_inactive_agent = assignment_type_settings.try(:[], :reassign_conversation_of_inactive_agent)
          return missing_field_error(field_name) if reassign_conversation_of_inactive_agent.nil?

          invalid_data_type(field_name, 'Boolean', 'invalid') unless reassign_conversation_of_inactive_agent.in? [true, false]
          invalid_field_error(ERROR_KEY_MAPPINGS[:capping_limit]) if assignment_type_settings.try(:[], :capping_limit).present?
        end
      end

      def validate_unique_channel_settings(channel_name, settings_hash)
        field_name = 'automatic_agent_assignment[:settings]'.to_sym
        if settings_hash.count > 1
          errors[field_name] << :can_have_only_one_field
          (self.error_options ||= {})[field_name] = { list: channel_name }
          false
        end
        true
      end

      def validate_ticket_lbrr_settings
        field_name = ERROR_KEY_MAPPINGS[:assignment_type]
        setting = grouped_settings[CHANNEL_NAMES[:freshdesk].to_sym]&.first || {}
        setting[:assignment_type] == ASSIGNMENT_TYPE_MAPPINGS[LOAD_BASED_ROUND_ROBIN] && errors[field_name] << :lbrr_not_supported
      end

      def grouped_settings
        @grouped_settings ||= @settings.group_by { |c| c[:channel].to_s.try(:to_sym) }
      end

      def channel_specific?
        @automatic_agent_assignment.present? && @automatic_agent_assignment[:type] == CHANNEL_SPECIFIC
      end

      def omni_channel?
        @automatic_agent_assignment.present? && @automatic_agent_assignment[:type] == OMNI_CHANNEL
      end

      def valid_capping_limit?(setting)
        if ASSIGNMENT_TYPES_WITH_CAPPING_LIMIT.include? setting[:assignment_type]
          assignment_type_settings = setting[:assignment_type_settings]
          field_name = 'automatic_agent_assignment[:settings][:assignment_type]'.to_sym
          missing_field_error(field_name) && return if assignment_type_settings.blank?
          capping_limit = assignment_type_settings.try(:[], :capping_limit)
          if capping_limit.nil? 
            errors[:capping_limit] << :capping_limit_is_missing
          elsif !capping_limit.between?(1,100)
            errors[:capping_limit] << :invalid_range
          end
        end
      end

      def invalid_field_error(field_name)
        errors[field_name] << :invalid_field
      end

      def missing_field_error(field_name)
        errors[field_name] << :missing_or_blank
      end

      def invalid_channels_error(field_name, list)
        errors[field_name] << :invalid_channels
        error_message = {}
        error_message[field_name] = { list: list }
        error_options.merge!(error_message)
      end

  end
end

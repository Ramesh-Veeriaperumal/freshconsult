module Admin
  class AutomationValidation < ApiValidation
    include Admin::AutomationConstants
    include Admin::AutomationValidationHelper

    attr_accessor(*AutomationConstants::PERMITTED_PARAMS)
    attr_accessor :type_name, :rule_type, :field_position

    validates :name, presence: true, on: :create
    validates :name, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING },
                     if: -> { name.present? }

    validates :performer, presence: true, data_type: { rules: Hash }, if: -> { observer_rule? }, on: :create
    validates :events, presence: true, data_type: { rules: Array }, if: -> { observer_rule? }, on: :create
    validates :conditions, presence: true, data_type: { rules: Hash }, if: -> { !observer_rule? }, on: :create
    validates :actions, presence: true, data_type: { rules: Array }, on: :create

    validates :performer, presence: true, data_type: { rules: Hash }, if: -> { observer_rule? && @request_params.key?(:performer) }, on: :update
    validates :events, presence: true, data_type: { rules: Array }, if: -> { observer_rule? && @request_params.key?(:events) }, on: :update
    validates :conditions, data_type: { rules: Hash }, if: -> { @request_params.key?(:conditions) }, on: :update
    validates :conditions, presence: true, if: -> { @request_params.key?(:conditions) && !observer_rule? }, on: :update
    validates :actions, presence: true, data_type: { rules: Array }, if: -> { @request_params.key?(:actions) }, on: :update

    validate :unpermitted_params
    validate :validate_params
    validate :system_event, if: -> { performer.present? && events.present? && events.is_a?(Array) }

    def initialize(request_params, cf_fields, item = nil, allow_string_param = false)
      @request_params = request_params
      @type_name = :rule
      AutomationConstants::PERMITTED_PARAMS.each do |param|
        safe_send("#{param}=", request_params[param])
      end
      cf_fields.each_pair {|key, value| safe_send("#{key}=", value) }
      self.skip_hash_params_set = true
      super(request_params, item, allow_string_param)
    end

    private

      def validate_params
        return if errors.present?

        validate_position if position.present?
        validate_performer if observer_rule? && performer.present?
        validate_events if observer_rule? && events.present?
        validate_actions if actions.present?
        validate_conditions if conditions.present?
      end

      def validate_position
        unless position.is_a?(Integer)
          errors[:position] << :invalid_data_type
          error_options[:position] = { expected_type: Integer, actual_type: position.class }
        end
      end

      def system_event
        if performer[:type] == 4
          system_observer_events
          events.each do |event|
            unexpected_parameter(event[:field_name]) unless SYSTEM_EVENT_FIELDS.include?(event[:field_name].to_sym)
          end
        else 
          events.each do |event|
            unexpected_parameter(event[:field_name]) if SYSTEM_EVENT_FIELDS.include?(event[:field_name].to_sym)
          end
        end
      end

      def validate_performer
        performer_validation = Admin::AutomationRules::PerformerValidation.new(performer, nil, false)
        if performer_validation.invalid?
          merge_to_parent_errors(performer_validation)
          error_options.merge! performer_validation.error_options
        end
      end

      def validate_events
        event_validation = Admin::AutomationRules::Events::TicketValidation.new(events, custom_ticket_event, rule_type)
        is_valid = event_validation.valid?
        unless is_valid
          merge_to_parent_errors(event_validation)
          error_options.merge! event_validation.error_options
        end
        is_valid
      end

      def validate_actions
        action_validation = Admin::AutomationRules::Actions::TicketValidation.new(actions, custom_ticket_action, rule_type)
        is_valid = action_validation.valid?
        unless is_valid
          merge_to_parent_errors(action_validation)
          error_options.merge! action_validation.error_options
        end
      end

      def validate_conditions
        self.type_name = :conditions
        previous = true
        set_count = 0
        (1..Admin::AutomationConstants::MAXIMUM_CONDITIONAL_SET_COUNT).each do |set|
          name = :"condition_set_#{set}"
          current = condition_set_present?(name)
          invalid_condition_error(name) if set == 1 && !current
          if current
            set_count += 1
            # if condition_set_1 is not available and condition_set_2 given, its invalid and so on.
            self.type_name = :conditions
            return invalid_condition_set(set) unless previous
            # Supervisor have only one Condition Set
            return unexpected_parameter(name) if supervisor_rule? && set != 1
            # validate match type
            valid_match_type?(name, conditions[name][:match_type])
            # validate operator joining condition set
            valid_condition_set_operator?(conditions[:operator]) if set > 1
            # validate inside condition set
            (CONDITION_SET_REQUEST_PARAMS - MATCH_TYPE_NAME).each do |field_type|
              validate_conditions_properties(set, field_type)
            end
          end
          previous = current
        end
        unexpected_parameter(:operator, message = :condition_set_operator_error) if conditions[:operator] && set_count == 1
      end

      def invalid_condition_error(name)
        field_missing = (CONDITION_SET_REQUEST_PARAMS - MATCH_TYPE_NAME)
        field_missing -= SUPERVISOR_IGNORE_CONDITION_PARAMS if supervisor_rule?
        missing_field_error(name, field_missing.join(','))
      end

      def valid_condition_set_operator?(operator)
        unless Admin::AutomationConstants::CONDITION_SET_OPERATOR.include?(operator)
          self.type_name = :conditions
          not_included_error(:operator, Admin::AutomationConstants::CONDITION_SET_OPERATOR)
        end
      end
      def valid_match_type?(name, match_type)
        unless Admin::AutomationConstants::MATCH_TYPE.include?(match_type)
          self.type_name = :"conditions[#{name}]"
          invalid_value_list(:match_type, Admin::AutomationConstants::MATCH_TYPE)
        end
      end

      def validate_conditions_properties(set, field_type)
        validate_class = "Admin::AutomationRules::Conditions::#{field_type.to_s.camelcase}Validation".constantize
        additional_options = { events: events, performer: performer }
        condition_validation = validate_class.new(conditions[:"condition_set_#{set}"][field_type], safe_send(:"custom_#{field_type}_condition"), set, rule_type, additional_options)
        is_valid = condition_validation.valid?(validation_context)
        unless is_valid
          merge_to_parent_errors(condition_validation)
          error_options.merge! condition_validation.error_options
        end
      end

      def condition_set_present?(set_name)
        return false if conditions[set_name].blank?
        (CONDITION_SET_REQUEST_PARAMS - MATCH_TYPE_NAME).any? do |type|
          next if supervisor_rule? && SUPERVISOR_IGNORE_CONDITION_PARAMS.include?(type)
          conditions[set_name][type].present?
        end
      end

      def unpermitted_params
        unless observer_rule?
          rule = I18n.t('admin.home.index.observer_new_name')
          unexpected_value_for_attribute(:events, rule, message=:invalid_attribute_for_rules) if @request_params.key?(:events)
          unexpected_value_for_attribute(:performer, rule, message=:invalid_attribute_for_rules) if @request_params.key?(:performer)
        end
        if supervisor_rule?
          condition = @request_params[:conditions]
          condition_set_1 = @request_params[:conditions].try(:[], :condition_set_1) || {}
          condition_set_2 = condition.is_a?(Hash) && condition.key?(:condition_set_2)
          unexpected_parameter("conditions[:condition_set_2]") if condition_set_2.present?
          if condition_set_1.present? && condition_set_1.is_a?(Hash)
            unexpected_parameter("conditions[:condition_set_1][:contact]") if condition_set_1.key?(:contact)
            unexpected_parameter("conditions[:condition_set_1][:company]") if condition_set_1.key?(:company)
          end
        end
      end
  end
end

module Admin
  class AutomationValidation < ApiValidation
    include Admin::AutomationConstants
    include Admin::AutomationValidationHelper

    attr_accessor(*AutomationConstants::PERMITTED_PARAMS)
    attr_accessor :type_name, :rule_type, :field_position

    validates :name, presence: true, on: :create
    validates :name, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING },
                     if: -> { name.present? }
    validates :conditions, data_type: { rules: Array }, if: -> { conditions.present? }

    validates :performer, presence: true, data_type: { rules: Hash }, if: -> { observer_rule? }, on: :create
    validates :events, presence: true, data_type: { rules: Array }, if: -> { observer_rule? }, on: :create
    validates :conditions, presence: true, data_type: { rules: Array }, if: -> { !observer_rule? }, on: :create
    validates :actions, presence: true, data_type: { rules: Array }, on: :create

    validates :performer, presence: true, data_type: { rules: Hash }, if: -> { observer_rule? && @request_params.key?(:performer) }, on: :update
    validates :events, presence: true, data_type: { rules: Array }, if: -> { observer_rule? && @request_params.key?(:events) }, on: :update
    validates :conditions, data_type: { rules: Array }, if: -> { @request_params.key?(:conditions) }, on: :update
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
        validate_condition_set_operator(operator, conditions.try(:size), @request_params[:action] == 'update') if operator.present?
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
        condition_sets = conditions
        (1..Admin::AutomationConstants::MAXIMUM_CONDITIONAL_SET_COUNT).each do |set|
          break if condition_sets[set - 1].blank?

          validate_condition_set_names(condition_sets.map { |condition| condition[:name] })
          validate_default_conditions_params(condition_sets[set - 1], set.to_i)
          CONDITION_RESOURCE_TYPES.each do |field_type|
            properties = condition_sets[set - 1][:properties]
            next if properties.blank? || !properties.is_a?(Array)

            condition = construct_condition_validation_params(properties, field_type)
            validate_conditions_properties(set, field_type, condition)
          end
        end
      end

      def unpermitted_params
        unless observer_rule?
          rule = I18n.t('admin.home.index.observer_new_name')
          unexpected_value_for_attribute(:events, rule, message=:invalid_attribute_for_rules) if @request_params.key?(:events)
          unexpected_value_for_attribute(:performer, rule, message=:invalid_attribute_for_rules) if @request_params.key?(:performer)
        end
      end
  end
end

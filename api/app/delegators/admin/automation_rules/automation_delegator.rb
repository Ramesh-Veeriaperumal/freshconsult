module Admin::AutomationRules
  class AutomationDelegator < BaseDelegator
    include Admin::AutomationDelegatorHelper
    include Admin::AutomationConstants

    attr_accessor(*VA_ATTRS)
    attr_accessor :rule_type

    validate :position_valid?, if: -> { position.present? }
    validate :validate_conditions, if: -> { conditions.present? }
    validate :validate_events, if: -> { events.present? && observer_rule? }
    validate :validate_actions, if: -> { actions.present? }
    validate :validate_performer, if: -> { performer.present? && observer_rule? }
    validate :validate_active, if: -> { active.present? }
    validate :validate_name

    def initialize(record, options = {}, rule_type)
      VA_ATTRS.each do |attr|
        instance_variable_set("@#{attr}", record[attr])
      end
      instance_variable_set("@rule_type", rule_type)
      @rule = record
      @options = options
      super(record)
    end

    private

    def validate_name
      duplicate_rule_name_error(name) if current_account.account_va_rules.where("rule_type = ? AND name = ?", rule_type, name).present?
    end

    def validate_active
      not_included_error('active', BOOLEAN) unless BOOLEAN.include? active
    end

    def position_valid?
      rule_count ||= current_account.safe_send(VAConfig::ASSOCIATION_MAPPING[VAConfig::RULES_BY_ID[rule_type]]).count
      if position < 1 || position > rule_count
        errors[:position] << :invalid_position
        error_options[:position] = { max_position: rule_count + 1 }
      end
    end

    def validate_conditions
      conditions.each do |condition_set|
        condition_set = condition_set.symbolize_keys
        grouped_condition_set = group_by_resource_type(condition_set[:properties]).symbolize_keys
        RESOURCE_TYPES.each do |resource_type|
          evaluate_on_condition(resource_type, grouped_condition_set[resource_type]) if grouped_condition_set.key? resource_type
        end
      end
    end

    def group_by_resource_type(conditions_set)
      conditions_set.group_by { |c| c[:resource_type] || :ticket }
    end

    def evaluate_on_condition(evaluate_on, condition_set)
      condition_delegator_klass ="Admin::Conditions::#{evaluate_on.to_s.capitalize}Delegator".constantize
      condition_delegator = condition_delegator_klass.new(@rule, condition_set)
      merge_errors(condition_delegator) if condition_delegator.invalid?
    end

    def validate_events
      event_delegator = Admin::AutomationRules::Events::TicketDelegator.new(@rule, @options)
      merge_errors(event_delegator) if event_delegator.invalid?
    end
    
    def validate_actions
      action_delegator = Admin::AutomationRules::Actions::TicketDelegator.new(@rule, @options)
      merge_errors(action_delegator) if action_delegator.invalid?
    end

    def validate_performer
      performer_delegator = Admin::AutomationRules::Performer::PerformerDelegator.new(@rule, @options)
      merge_errors(performer_delegator) if performer_delegator.invalid?
    end

    def current_account
      @account ||= Account.current
    end
    
    def merge_errors(delegator)
      errors.messages.merge!(delegator.errors.messages)
      error_options.merge!(delegator.error_options)
    end
  end
end

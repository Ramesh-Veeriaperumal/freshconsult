class ConditionsDelegator < BaseDelegator
  include Admin::AutomationDelegatorHelper
  include Admin::ConditionErrorHelper

  RESOURCE_TYPES = %i[ticket contact company].freeze
  validate :validate_conditions, if: -> { @conditions.present? }

  def initialize(record, conditions)
    @conditions = conditions
    @item = record
    super(record)
  end

  private

    def validate_conditions
      RESOURCE_TYPES.each do |resource_type|
        grouped_conditions = group_by_resource_type(@conditions, resource_type)
        next unless grouped_conditions

        evaluate_on_condition(resource_type, grouped_conditions)
      end
    end

    def group_by_resource_type(conditions, resource_type)
      conditions = conditions.group_by { |cond| cond[:resource_type].try(:to_sym) || :ticket }[resource_type]
      conditions.present? ? conditions.map { |condition| condition.except!(:resource_type) } : nil
    end

    def evaluate_on_condition(resource_type, conditions)
      condition_delegator_klass = "Admin::Conditions::#{resource_type.to_s.capitalize}Delegator".constantize
      condition_delegator = condition_delegator_klass.new(@item, conditions)
      unless condition_delegator.valid?
        merge_to_parent_errors(condition_delegator)
        error_options.merge! condition_delegator.error_options
      end
    end
end

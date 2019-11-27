class AdminSubscriptionDelegator < BaseDelegator
  attr_accessor :plan_id, :currency
  validate :validate_plan_id, on: :update, if: -> { @plan_id.present? }
  validate :validate_estimate_on_free_plan, on: :estimate, if: -> { @plan_id.present? }
  validate :validate_renewal_period_based_on_plan, on: :estimate
  validate :validate_subscription_state, on: :update, if: -> { @currency.present? }

  def initialize(item, options = {})
    @plan_id = options[:plan_id]
    @currency = options[:currency]
    @subscription = Account.current.subscription
    super(item, options)
  end

  def validate_plan_id
    errors[:plan_id] << :invalid_plan_id unless SubscriptionPlan.cached_current_plans.map(&:id).include?(@plan_id.to_i)
  end

  def validate_renewal_period_based_on_plan
    errors[:renewal_period] << :cannot_apply_renewal_period if (@plan_id.blank? || @plan_id.to_i == @subscription.plan_id) && @subscription.subscription_plan.amount.zero?
  end

  def validate_estimate_on_free_plan
    subscription_plan = SubscriptionPlan.find_by_id(@plan_id)
    errors[:plan_id] << :cannot_estimate_free_plan if subscription_plan.present? && subscription_plan.amount.zero?
  end

  def validate_subscription_state
    if @subscription.active?
      errors[:currency] << :cannot_update_currency_unless_free_plan
      error_options[:currency] = { account_state: @subscription.state }
    end
  end
end

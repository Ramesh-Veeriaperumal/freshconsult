module AuditLog::Translators::Subscription
  def readable_subscription_changes(model_changes)
    model_changes.keys.each do |attribute|
      case attribute
      when :renewal_period
        model_changes[attribute] = [
          SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[model_changes[attribute][0]],
          SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[model_changes[attribute][1]]
        ]
      when :subscription_currency_id
        model_changes[attribute] = [
          currencies.find { |c| c.id == model_changes[attribute][0] }.name,
          currencies.find { |c| c.id == model_changes[attribute][1] }.name
        ]
      when :subscription_plan_id
        plans = SubscriptionPlan.all
        model_changes[attribute] = [
          plans.find { |plan| plan.id == model_changes[attribute][0] }.display_name,
          plans.find { |plan| plan.id == model_changes[attribute][1] }.display_name
        ]
      end
    end
    model_changes
  end

  def currencies
    @currencies ||= Subscription::Currency.all
  end
end

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
          currencies.find { |c| c.id == model_changes[attribute][0] }.try(:name).to_s,
          currencies.find { |c| c.id == model_changes[attribute][1] }.try(:name).to_s
        ]
      when :subscription_plan_id
        model_changes[attribute] = [
          plans.find { |plan| plan.id == model_changes[attribute][0] }.try(:display_name).to_s,
          plans.find { |plan| plan.id == model_changes[attribute][1] }.try(:display_name).to_s
        ]
      end
    end
    model_changes
  end

  def currencies
    @currencies ||= Subscription::Currency.all
  end

  def plans
    @plans ||= SubscriptionPlan.all
  end
end

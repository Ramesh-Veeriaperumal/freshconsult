module AuditLog::SubscriptionHelper
  include AuditLog::AuditLogHelper

  ALLOWED_MODEL_CHANGES = [:state, :renewal_period, :subscription_plan_id,
    :agent_limit, :subscription_currency_id, :card_number, :card_expiration].freeze

  def subscription_changes(model_data, changes)
    response = []
    changes.deep_symbolize_keys
    model_name = :subscription
    changes.each_pair do |key, value|
      next unless ALLOWED_MODEL_CHANGES.include?(key)
      trans_key = translated_key(key, model_name)
      response << case key
                  when :renewal_period
                    billing_object(trans_key, value)
                  when :amount
                    money_object(trans_key, value, model_data[:subscription_currency_id])
                  when :next_renewal_at
                    description_properties(trans_key, value, type: :date)
                  when :subscription_currency_id
                    subscription_currency(value, trans_key)
                  when :subscription_plan_id
                    subscription_plan(value, trans_key)
                  else
                    description_properties(trans_key, value)
                  end
    end
    response
  end

  private

  def billing_object(key, value)
    description_properties(key, translated_value(:BILLING_CYCLE, value))
  end

  def money_object(key, value, currency_id)
    description_properties(key, value, type: :currency,
      currency: subscription_currencies.find { |subscription_currency| 
        subscription_currency.id == currency_id 
      }.name)
  end

  def subscription_currency(value, trans_key)
    subscription_currency = subscription_currencies.map do |currency|
      currency.name if value.include?(currency.id)
    end.compact
    changed_currency_value = compare_sort(subscription_currency, *value)
    description_properties(trans_key, changed_currency_value)
  end

  def subscription_plan(value, trans_key)
    subscription_plan = subscription_plans.map do |plan|
      plan.name if value.include?(plan.id)
    end.compact
    changed_subscription_plan = compare_sort(subscription_plan, *value)
    description_properties(trans_key, changed_subscription_plan)
  end

  def compare_sort(value, obj1_x, obj1_y)
    value.sort do |obj2_x, obj2_y|
      obj1_x < obj1_y ? obj2_x <=> obj2_y : obj2_y <=> obj2_x
    end
  end

  def subscription_currencies
    @currencies ||= Subscription::Currency.all
  end

  def subscription_plans
    @plans ||= SubscriptionPlan.all
  end
end

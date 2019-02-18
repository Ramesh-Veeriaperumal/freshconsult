module AuditLog::SubscriptionHelper
  include AuditLog::AuditLogHelper
  include AuditLog::Translators::Subscription

  ALLOWED_MODEL_CHANGES = [:state, :renewal_period, :subscription_plan_id,
    :agent_limit, :subscription_currency_id, :card_number, :card_expiration].freeze

  def subscription_changes(model_data, changes)
    return [] unless User.current.privilege?(:manage_account)
    response = []
    changes = readable_subscription_changes(changes)
    model_name = :subscription
    changes.each_pair do |key, value|
      next unless ALLOWED_MODEL_CHANGES.include?(key)
      trans_key = translated_key(key, model_name)
      response.push key == :amount ? 
                    money_object(trans_key, value, model_data[:subscription_currency_id]) : 
                    description_properties(trans_key, value)
    end
    response
  end

  private

  def money_object(key, value, currency_id)
    description_properties(key, value, type: :currency,
      currency: subscription_currencies.find { |subscription_currency| 
        subscription_currency.id == currency_id 
      }.name)
  end
end

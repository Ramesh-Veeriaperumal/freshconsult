class AdminSubscriptionValidation < ApiValidation
  attr_accessor :currency, :agent_seats, :renewal_period, :plan_id

  validates :currency, custom_inclusion: { in: Subscription::Currency.currency_names_from_cache }
  validates :agent_seats, :renewal_period, required: true, allow_nil: false, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }, on: :estimate
  validates :plan_id, allow_nil: false, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }, on: :estimate
  validates :renewal_period, custom_inclusion: { in: AdminSubscriptionConstants::VALID_BILLING_CYCLES }
end

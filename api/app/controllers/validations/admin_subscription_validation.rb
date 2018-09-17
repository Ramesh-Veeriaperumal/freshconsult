class AdminSubscriptionValidation < ApiValidation
  attr_accessor :currency

  validates :currency, custom_inclusion: { 
    in: Subscription::Currency.currency_names_from_cache 
  }
end
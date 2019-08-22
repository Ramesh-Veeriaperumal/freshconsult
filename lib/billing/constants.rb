module Billing::Constants

  INVOICE_EVENTS = ['invoice_generated', 'invoice_updated', 'invoice_deleted'].freeze

  EVENTS = [ "subscription_changed", "subscription_activated", "subscription_renewed",
              "subscription_cancelled", "subscription_scheduled_cancellation_removed", "subscription_reactivated", "card_added",
              "card_updated", "payment_succeeded", "payment_refunded", "card_deleted",
              "customer_changed", 'card_expiring'].freeze + INVOICE_EVENTS

  ADDITIONAL_INVOICE_EVENTS = ['payment_succeeded', 'subscription_cancelled' ].freeze

  ALL_INVOICE_EVENTS = INVOICE_EVENTS + ADDITIONAL_INVOICE_EVENTS

  LIVE_CHAT_EVENTS = [ "subscription_activated", "subscription_renewed", "subscription_cancelled",
                        "subscription_reactivated", "subscription_changed"]

  # Events to be synced for all sources including API.
  SYNC_EVENTS_ALL_SOURCE = [ "payment_succeeded", "payment_refunded", "subscription_reactivated" ]

  ADDONS_TO_IGNORE = ["bank_charges_monthly", "bank_charges_quarterly", "bank_charges_half_yearly",
    "bank_charges_annual"]

  INVOICE_TYPES = {
    :recurring => "0",
    :non_recurring => "1"
  }

  EVENT_SOURCES = {
    :api => "api"
  }

  META_INFO = { :plan => :subscription_plan_id, :renewal_period => :renewal_period,
                :agents => :agent_limit, :free_agents => :free_agents }

  ADDRESS_INFO = { :first_name => :first_name, :last_name => :last_name, :address1 => :billing_addr1,
                    :address2 => :billing_addr2, :city => :billing_city, :state => :billing_state,
                    :country => :billing_country, :zip => :billing_zip  }

  IN_TRIAL = "in_trial"
  CANCELLED = "cancelled"
  NO_CARD = "no_card"
  OFFLINE = "off"
  PAID = "paid"
  VOIDED = 'voided'
  CARD_STATUS = 'valid'

  PAYMENT_DUE = 'payment_due'.freeze

  TRIAL = "trial"
  FREE = "free"
  ACTIVE = "active"
  SUSPENDED = "suspended"

  ONLINE_CUSTOMER = "on"

  TRUE = "true"
  
  INVOICE_DUE_EXPIRY = 60.days
end

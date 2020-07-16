class Subscription < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at, :next_renewal_at, :discount_expires_at]
  SUBSCRIPTION_UPDATE = 'subscription_update'.freeze
  SUBSCRIPTION_CREATE = 'subscription_create'.freeze

  acts_as_api

  api_accessible :central_publish do |s|
    s.add :id
    s.add proc { |s| s.amount.to_i }, as: :amount
    s.add :card_number
    s.add :card_expiration
    s.add :state
    s.add :subscription_plan_id
    s.add :account_id
    s.add :renewal_period
    s.add :billing_id
    s.add :subscription_discount_id
    s.add :subscription_affiliate_id
    s.add :agent_limit
    s.add :free_agents
    s.add proc { |s| s.day_pass_amount.to_i }, as: :day_pass_amount
    s.add :subscription_currency_id
    s.add proc { |ap| ap.subscription_plan.display_name }, as: :account_plan
    s.add proc { |ap| ap.subscription_plan.name }, as: :plan_name
    DATETIME_FIELDS.each do |key|
      s.add proc { |d| d.utc_format(d.safe_send(key)) }, as: key
    end
    s.add proc { |x| x.currency.name }, as: :currency
    s.add proc { |x| x.currency.exchange_rate.to_f }, as: :exchange_rate
  end

  def event_info action
    {
      ip_address: Thread.current[:current_ip],
      pod: ChannelFrameworkConfig['pod']
    }
  end

  def model_changes_for_central
    self.previous_changes
  end

  def self.disallow_payload?(payload_type)
    return false if payload_type == SUBSCRIPTION_UPDATE

    super
  end

  def relationship_with_account
    "subscription"
  end

  def bundle_info(payload_type)
    return {} unless [SUBSCRIPTION_CREATE, SUBSCRIPTION_UPDATE].include?(payload_type)

    {
      bundle: {
        type: Account.current.omni_bundle_name
      }
    }
  end
end

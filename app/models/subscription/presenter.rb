class Subscription < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at, :next_renewal_at, :discount_expires_at]

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
    DATETIME_FIELDS.each do |key|
      s.add proc { |d| d.utc_format(d.safe_send(key)) }, as: key
    end
  end

  def self.central_publish_enabled?
    Account.current.audit_logs_central_publish_enabled?
  end

  def event_info action
    { :ip_address => Thread.current[:current_ip] }
  end

  def model_changes_for_central
    self.previous_changes
  end

  def readable_model_changes(model_changes)
    model_changes.keys.each do |attribute|
      case attribute
      when "renewal_period"
        model_changes[attribute] = [
          SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[model_changes[attribute][0]],
          SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[model_changes[attribute][1]]
        ]
      when "subscription_currency_id"
        currencies = Subscription::Currency.all
        model_changes[attribute] = [
          currencies.find { |c| c.id == model_changes[attribute][0] }.name,
          currencies.find { |c| c.id == model_changes[attribute][1] }.name
        ]
      when "subscription_plan_id"
        plans = SubscriptionPlan.all
        model_changes[attribute] = [
          plans.find { |plan| plan.id == model_changes[attribute][0] }.display_name,
          plans.find { |plan| plan.id == model_changes[attribute][1] }.display_name
        ]
      end
    end
    model_changes
  end

  def relationship_with_account
    "subscription"
  end
end

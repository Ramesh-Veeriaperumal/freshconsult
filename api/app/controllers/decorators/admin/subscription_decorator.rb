class Admin::SubscriptionDecorator < ApiDecorator
  include SubscriptionsHelper

  delegate :id, :state, :subscription_plan_id, :renewal_period, :next_renewal_at, :created_at,
           :updated_at, :agent_limit, :card_number, :card_expiration, :billing_address, to: :record
  EVENT_TYPE = 'plan'.freeze

  def initialize(record, options)
    super(record)
    @currency = options[:currency]
    @plans_to_agent_cost = options[:plans_to_agent_cost]
    @immediate_subscription_estimate = options[:immediate_subscription_estimate]
    @future_subscription_estimate = options[:future_subscription_estimate]
    @update_payment_site = options[:update_payment_site]
  end

  def to_hash
    {
      id: id,
      state: state,
      plan_id: subscription_plan_id,
      renewal_period: renewal_period,
      next_renewal_at: next_renewal_at,
      days_remaining: (record.next_renewal_at.utc.to_date - Time.now.utc.to_date).to_i,
      agent_seats: agent_limit,
      card_number: card_number,
      card_expiration: card_expiration,
      name_on_card: (billing_address.name_on_card if billing_address.present?),
      reseller_paid_account: record.reseller_paid_account?,
      switch_to_annual_percentage: record.percentage_difference,
      subscription_request: subscription_request_hash,
      updated_at: updated_at.try(:utc),
      created_at: created_at.try(:utc),
      currency: currency_info,
      addons: addon_hash,
      paying_account: record.paying_account?,
      update_payment_site: @update_payment_site,
      features_gained: record.additional_info[:feature_gain],
      discount: record.additional_info[:discount],
      offline: record.offline_subscription?
    }
  end

  def plan_hash
    plan_name = record.name
    {
      id: id,
      name: plan_name,
      currency: @currency,
      pricings: construct_pricings(plan_name)
    }
  end

  def estimate_hash
    next_billing_at = Time.zone.at(@immediate_subscription_estimate['subscription_estimate']['next_billing_at']).to_datetime
    ret_hash = {
      agent_seats: agent_limit,
      renewal_period: renewal_period,
      plan_id: subscription_plan_id,
      immediate_invoice: immediate_invoice_hash,
      next_invoice: next_invoice_hash(next_billing_at),
      tax_inclusive: tax_inclusive?(record)
    }
    plan_item = @future_subscription_estimate.estimate.line_items.detect { |item| item.entity_type == EVENT_TYPE }
    ret_hash[:plan_cost] = modified_amount(plan_item.unit_amount / renewal_period)
    available_credit = 0
    if @immediate_subscription_estimate['credit_note_estimates'].present?
      @immediate_subscription_estimate['credit_note_estimates'].each do |credit|
        available_credit += credit['amount_available']
      end
    end
    ret_hash[:credit_amount_available] = modified_amount(available_credit)
    ret_hash
  end

  def immediate_invoice_hash
    ret_hash = {}
    discount_amount = 0
    invoice_estimate = @immediate_subscription_estimate['invoice_estimate']
    if invoice_estimate.present?
      if invoice_estimate['discounts'].present?
        invoice_estimate['discounts'].each do |discount|
          discount_amount += discount['amount']
        end
      end
      invoice_item = invoice_estimate['line_items'][0]
      invoice_from = Time.zone.at(invoice_item['date_from']).to_datetime
      invoice_to = Time.zone.at(invoice_item['date_to']).to_datetime
      ret_hash = {
        date_from: invoice_from,
        date_to: invoice_to,
        amount: modified_amount(invoice_estimate['total']),
        amount_due: modified_amount(invoice_estimate['amount_due']),
        credits_applied: modified_amount(invoice_estimate['credits_applied']),
        discount_amount: modified_amount(discount_amount),
        days_remaining: (invoice_to - Time.zone.now.to_datetime).to_i
      }
    end
    ret_hash
  end

  def next_invoice_hash(next_billing_at)
    discount_amount = 0
    invoice_estimate = @future_subscription_estimate.estimate
    invoice_estimate.discounts.each do |discount|
      discount_amount += discount.amount
    end
    {
      date_from: next_billing_at,
      date_to: (next_billing_at + renewal_period.months),
      amount: modified_amount(invoice_estimate.amount),
      discount_amount: modified_amount(discount_amount)
    }
  end

  def addon_hash
    return if record.addons.empty?
    addons = []
    record.addons.each do |addon|
      addons << { id: addon.id, name: addon.name, features_list: addon.features.collect(&:to_s) }
    end
    addons
  end

  def currency_info
    record.currency.name
  end

  def construct_pricings(plan_name)
    Billing::Subscription::BILLING_PERIOD.values.collect do |billing_cycle|
      {
        billing_cycle: billing_cycle,
        cost_per_agent: @plans_to_agent_cost[plan_name][billing_cycle]
      }
    end
  end

  def modified_amount(amount)
    amount / 100
  end

  def subscription_request_hash
    return if record.subscription_request.blank?

    subscription_request = record.subscription_request
    request_hash = { plan_name: subscription_request.plan_name,
                     feature_loss: subscription_request.feature_loss?,
                     products_limit_exceeded: subscription_request.product_loss?
                   }
    unless subscription_request.subscription_plan.amount.zero?
      request_hash.merge!(
        agent_seats: subscription_request.agent_limit,
        renewal_period: subscription_request.renewal_period,
        fsm_field_agents: subscription_request.fsm_field_agents
      )
    end
    request_hash
  end
end

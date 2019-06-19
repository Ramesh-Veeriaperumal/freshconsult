class Admin::SubscriptionDecorator < ApiDecorator
  delegate :id, :state, :subscription_plan_id, :renewal_period, :agent_limit, :card_number, :card_expiration, :billing_address, to: :record

  def initialize(record, options)
    super(record)
    @currency = options[:currency]
    @plans_to_agent_cost = options[:plans_to_agent_cost]
    @immediate_subscription_estimate = options[:immediate_subscription_estimate]
    @future_subscription_estimate = options[:future_subscription_estimate]
  end

  def to_hash
    {
      id: id,
      state: state,
      plan_id: subscription_plan_id,
      renewal_period: renewal_period,
      agent_seats: agent_limit,
      card_number: card_number,
      card_expiration: card_expiration,
      name_on_card: (billing_address.name_on_card if billing_address.present?),
      updated_at: updated_at,
      created_at: created_at,
      currency: currency_info,
      addons: addon_hash
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
      next_invoice: next_invoice_hash(next_billing_at)
    }
    allocated_credit = 0
    available_credit = 0
    if @immediate_subscription_estimate['credit_note_estimates'].present?
      @immediate_subscription_estimate['credit_note_estimates'].each do |credit|
        allocated_credit += credit['amount_allocated']
        available_credit += credit['amount_available']
      end
    end
    ret_hash[:credit_amount_allocated] = (allocated_credit / 100)
    ret_hash[:credit_amount_available] = (available_credit / 100)
    ret_hash
  end

  def immediate_invoice_hash
    ret_hash = {}
    invoice_estimate = @immediate_subscription_estimate['invoice_estimate']
    if invoice_estimate.present?
      invoice_item = invoice_estimate['line_items'][0]
      invoice_from = Time.zone.at(invoice_item['date_from']).to_datetime
      invoice_to = Time.zone.at(invoice_item['date_to']).to_datetime
      ret_hash = {
        date_from: invoice_from,
        date_to: invoice_to,
        amount: (invoice_estimate['amount_due'] / 100),
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
      amount: invoice_estimate.amount / 100,
      discount_amount: discount_amount / 100
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
end

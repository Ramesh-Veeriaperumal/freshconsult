class Admin::SubscriptionDecorator < ApiDecorator
  delegate :id, :state, :subscription_plan_id, to: :record

  def initialize(record, options)
    super(record)
    @currency = options[:currency]
    @plans_to_agent_cost = options[:plans_to_agent_cost]
  end

  def to_hash
    {
      id: id,
      state: state,
      subscription_plan_id: subscription_plan_id,
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

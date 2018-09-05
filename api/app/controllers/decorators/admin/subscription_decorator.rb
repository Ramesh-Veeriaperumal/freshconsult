class Admin::SubscriptionDecorator < ApiDecorator
  delegate :id, :state, :subscription_plan_id,to: :record

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
end

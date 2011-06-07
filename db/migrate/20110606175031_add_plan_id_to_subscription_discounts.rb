class AddPlanIdToSubscriptionDiscounts < ActiveRecord::Migration
  def self.up
    add_column :subscription_discounts, :plan_id, :integer
  end

  def self.down
    remove_column :subscription_discounts, :plan_id
  end
end

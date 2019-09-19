class PopulateOmniPlansAmount < ActiveRecord::Migration
  shard :none
  def self.up
    execute "update subscription_plans set amount=45.0 where name = 'Garden Omni Jan 19'"
    execute "update subscription_plans set amount=85.0 where name = 'Estate Omni Jan 19'"
  end

  def self.down
  end
end

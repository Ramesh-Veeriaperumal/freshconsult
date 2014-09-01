class PopulateSubscriptionAddons < ActiveRecord::Migration
  shard :shard_1
  def self.up
  	addon_types = Subscription::Addon::ADDON_TYPES
  	addons = [ 
  		{ :name => "Agent Collision", :amount => 5.0, :renewal_period => 1, 
  			:addon_type => addon_types[:agent_quantity] },

  		{ :name => "Custom Ssl", :amount => 19.0, :renewal_period => 1, 
  			:addon_type => addon_types[:portal_quantity] },

  		{ :name => "Custom Roles", :amount => 5.0, :renewal_period => 1, 
  			:addon_type => addon_types[:agent_quantity] },

  		{ :name => "Gamification", :amount => 5.0, :renewal_period => 1, 
  			:addon_type => addon_types[:agent_quantity] },

  		{ :name => "Layout Customization", :amount => 49.0, :renewal_period => 1, 
  			:addon_type => addon_types[:portal_quantity] },

  		{ :name => "Multiple Business Hours", :amount => 5.0, :renewal_period => 1, 
  			:addon_type => addon_types[:agent_quantity] },

  		{ :name => "Round Robin", :amount => 3.0, :renewal_period => 1, 
  			:addon_type => addon_types[:agent_quantity] }]

    Subscription::Addon.create(addons)

    all_addons = Subscription::Addon.all
    garden_addons = all_addons - [ Subscription::Addon.find_by_name("Multiple Business Hours") ]

    SubscriptionPlan.find_by_name("Sprout").addons = all_addons
    SubscriptionPlan.find_by_name("Blossom").addons = all_addons
    SubscriptionPlan.find_by_name("Garden").addons = garden_addons
  end

  def self.down    
    execute <<-SQL
      DROP TABLE subscription_plan_addons;
    SQL
    execute <<-SQL
      DROP TABLE subscription_addons;
    SQL
  end
end

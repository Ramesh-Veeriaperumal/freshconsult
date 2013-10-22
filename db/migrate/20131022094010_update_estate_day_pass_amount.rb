class UpdateEstateDayPassAmount < ActiveRecord::Migration
  shard :none
  
  def self.up
    execute <<-SQL
      UPDATE subscriptions SET day_pass_amount = 3.00 WHERE subscription_plan_id IN 
    		(SELECT id FROM subscription_plans WHERE name IN ('Estate', 'Estate Classic'));
    SQL
    
    execute <<-SQL
      UPDATE subscription_plans SET day_pass_amount = 3.00 WHERE name IN ('Estate', 'Estate Classic');
    SQL
  end

  def self.down
    execute <<-SQL
      UPDATE subscription_plans SET day_pass_amount = 4.00 WHERE name IN ('Estate', 'Estate Classic');
    SQL
    
    execute <<-SQL
      UPDATE subscriptions SET day_pass_amount = 4.00 WHERE subscription_plan_id IN 
      	(SELECT id FROM subscription_plans WHERE name IN ('Estate', 'Estate Classic'));
    SQL
  end
end

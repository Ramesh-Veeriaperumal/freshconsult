class AddEnterpriseReportingFeature < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
      INSERT INTO features 
        (account_id, type, created_at, updated_at) 
        SELECT account_id, 'AdvancedReportingFeature', now(), now() FROM subscriptions inner join subscription_plans 
        on subscriptions.subscription_plan_id = subscription_plans.id where subscription_plans.name in 
        ('Pro','Blossom','Blossom Classic')
    SQL

		execute <<-SQL
      INSERT INTO features 
        (account_id, type, created_at, updated_at) 
        SELECT account_id, 'EnterpriseReportingFeature', now(), now() FROM subscriptions inner join subscription_plans 
        on subscriptions.subscription_plan_id = subscription_plans.id where subscription_plans.name in 
        ('Premium','Garden','Garden Classic','Estate','Estate Classic')
    SQL
  end

  def self.down
  	execute <<-SQL
	      DELETE FROM features WHERE type = 'EnterpriseReportingFeature'
	  SQL

	  execute <<-SQL
	      DELETE FROM features WHERE account_id in (SELECT account_id FROM subscriptions inner join subscription_plans 
        on subscriptions.subscription_plan_id = subscription_plans.id where subscription_plans.name in 
        ('Pro','Blossom','Blossom Classic')) and type = 'AdvancedReportingFeature'
	  SQL
  end
end

class AddPortalCssFeature < ActiveRecord::Migration
  def self.up
  	execute(%(INSERT INTO features(type, account_id, created_at, updated_at) (SELECT 
  		'CssCustomizationFeature', account_id, now(), now() FROM subscriptions 
  		INNER JOIN subscription_plans plans ON plans.id=subscriptions.subscription_plan_id 
  		WHERE plans.name IN ('Premium', 'Garden', 'Estate', 'GardenClassic', 'EstateClassic'))));
    
    execute(%(INSERT INTO features(type, account_id, created_at, updated_at) (SELECT 
    	'LayoutCustomizationFeature', account_id, now(), now() FROM subscriptions 
    	INNER JOIN subscription_plans plans ON plans.id=subscriptions.subscription_plan_id 
    	WHERE plans.name IN ('Estate', 'EstateClassic'))));
  end

  def self.down
  	execute("DELETE FROM features WHERE features.type = 'CssCustomizationFeature'");
  	execute("DELETE FROM features WHERE features.type = 'LayoutCustomizationFeature'");
  end
end

class AddMultipleBusinessHoursFeature < ActiveRecord::Migration
  def self.up
  	execute("insert into features (type, account_id, created_at, updated_at) select 'MultipleBusinessHoursFeature',
     account_id, now(), now() from features where type='EstateFeature'")
    execute("insert into features (type, account_id, created_at, updated_at) select 'MultipleBusinessHoursFeature',
     account_id, now(), now() from features where type='EstateClassicFeature'")
  end

  def self.down
  	execute("delete from features where type= 'MultipleBusinessHoursFeature'")
  end
end

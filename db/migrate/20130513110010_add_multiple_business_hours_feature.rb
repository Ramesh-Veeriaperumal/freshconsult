class AddMultipleBusinessHoursFeature < ActiveRecord::Migration
	shard :none
  def self.up
  	execute("insert into features (type, account_id, created_at, updated_at) select 'MultipleBusinessHoursFeature',account_id, now(), now() from features where type in ('EstateFeature','GardenFeature','EstateClassicFeature')")
  end

  def self.down
  	execute("delete from features where type= 'MultipleBusinessHoursFeature'")
  end
end

class PopulateDynamicContentFeature < ActiveRecord::Migration
	shard :none
  def self.up
  	execute %(insert into features (type, account_id, created_at, updated_at) select 'DynamicContentFeature', account_id, now(), now() 
  		from features where type='MultiLanguageFeature')
  end

  def self.down
  	execute %(delete from features where type = 'DynamicContentFeature')	 
  end
end

class AddResourceRLimitToAccountAdditionalSettings < ActiveRecord::Migration

	shard :all

  def change
  	add_column :account_additional_settings, :resource_rlimit_conf,  :text
  end
  
end

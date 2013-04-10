class AddTimestampsToEsEnabledAccount < ActiveRecord::Migration
  def self.up
  	add_timestamps(:es_enabled_accounts)
  end

  def self.down
  	remove_timestamps(:es_enabled_accounts)
  end
end

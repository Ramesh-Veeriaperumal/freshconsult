class AddSupportedLanguagesToAccountAdditionalSettings < ActiveRecord::Migration
	shard :none
  def self.up
  	Lhm.change_table :account_additional_settings, :atomic_switch => true do |m|
  		m.add_column :supported_languages, :text
  	end
  end

  def self.down
  	Lhm.change_table :account_additional_settings, :atomic_switch => true do |m|
  		m.remove_column :supported_languages
  	end
  end
end

class AddDateFormattingToAccount < ActiveRecord::Migration
	shard :all
	def self.up
  	Lhm.change_table :account_additional_settings,:atomic_switch => true do |m|
    	m.add_column :date_format,  "INT DEFAULT 1"
    end
  end

  def self.down
  	Lhm.change_table :account_additional_settings,:atomic_switch => true do |m|
    	m.remove_column :date_format
   	end
  end
end


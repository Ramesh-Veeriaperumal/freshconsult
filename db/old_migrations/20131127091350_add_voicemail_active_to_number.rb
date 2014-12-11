class AddVoicemailActiveToNumber < ActiveRecord::Migration
  shard :none
  def self.up
  	Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
  		m.add_column :voicemail_active, "tinyint(1) DEFAULT 0"
    end
  end

  def self.down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
  		m.remove_column :voicemail_active
    end
  end
end

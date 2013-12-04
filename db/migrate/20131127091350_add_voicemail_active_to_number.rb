class AddVoicemailActiveToNumber < ActiveRecord::Migration
  shard :none
  def self.up
    add_column :freshfone_numbers, :voicemail_active, :boolean, :default => false
  end

  def self.down
    remove_column :freshfone_numbers, :voicemail_active
  end
end

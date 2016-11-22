class UpdateTwilioClientVersionInFreshfoneAccounts < ActiveRecord::Migration
  shard :all

  def up
    Lhm.change_table :freshfone_accounts, atomic_switch: true do |m|
      m.change_column :twilio_client_version, "VARCHAR(10) DEFAULT '1.3'"
    end
  end

  def down
    Lhm.change_table :freshfone_accounts, atomic_switch: true do |m|
      m.change_column :twilio_client_version, "VARCHAR(10) DEFAULT '1.2'"
    end
  end
end

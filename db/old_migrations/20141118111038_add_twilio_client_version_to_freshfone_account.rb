class AddTwilioClientVersionToFreshfoneAccount < ActiveRecord::Migration
  shard :all
  def self.up
    add_column :freshfone_accounts, :twilio_client_version, :string, :default => "1.2", :limit => 10
  end

  def self.down
    remove_column :freshfone_accounts, :twilio_client_version
  end
end

class AddTriggerLevelValuesAndWhitelistedToFreshfoneAccounts < ActiveRecord::Migration
  shard :all
  
  def self.up
    
    Lhm.change_table :freshfone_accounts, :atomic_switch => true do |m|
      m.add_column :security_whitelist, "tinyint(1) DEFAULT 0"
      m.add_column :triggers, "text"
    end

    Freshfone::Account.find_in_batches(:batch_size => 300) do |ff_accnts|
      ff_accnts.each do |ff_acc|
        ff_acc.update_column(:triggers, {:first_level => 75, :second_level => 200}.to_yaml)      
      end
    end

  end

  def self.down

    Lhm.change_table :freshfone_accounts, :atomic_switch => true do |m|
      m.remove_column :triggers
  		m.remove_column :security_whitelist
    end
    
  end

end

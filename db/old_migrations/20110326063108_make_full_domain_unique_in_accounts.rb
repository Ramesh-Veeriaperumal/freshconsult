class MakeFullDomainUniqueInAccounts < ActiveRecord::Migration
  def self.up
    remove_index :accounts, [:full_domain]
    add_index :accounts, [:full_domain], :name => 'index_accounts_on_full_domain', :unique => true
  end

  def self.down
  end
end

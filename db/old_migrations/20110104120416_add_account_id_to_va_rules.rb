class AddAccountIdToVaRules < ActiveRecord::Migration
  def self.up
    add_column :va_rules, :account_id, :integer
  end

  def self.down
    remove_column :va_rules, :account_id
  end
end

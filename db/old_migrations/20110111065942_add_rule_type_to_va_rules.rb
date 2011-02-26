class AddRuleTypeToVaRules < ActiveRecord::Migration
  def self.up
    add_column :va_rules, :rule_type, :integer
  end

  def self.down
    remove_column :va_rules, :rule_type
  end
end

class AddColumnsToAppBusinessRules < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :app_business_rules, :atomic_switch => true do |m|
      m.add_column :installed_application_id, "bigint(20)"
      m.add_column :account_id, "bigint(20)"
      m.add_index  :installed_application_id, "index_app_business_rules_on_installed_app_id"
      m.add_index  :va_rule_id, "index_app_business_rules_on_varule_id"
    end
  end

  def down
    Lhm.change_table :app_business_rules, :atomic_switch => true do |m|
      m.remove_index  :installed_application_id
      m.remove_index  :va_rule_id
      m.remove_column :installed_application_id
      m.remove_column :account_id
    end
  end

end

# This AddIndexAccountIdRuleTypePositionToVaRules is responsible for adding index (account_id, rule_type, position) to va_rules
class AddIndexAccountIdRuleTypePositionToVaRules < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :va_rules, atomic_switch: true do |tbl|
      tbl.add_index([:account_id, :rule_type, :position], 'index_va_rules_on_account_id_rule_type_and_position')
    end
  end

  def down
    Lhm.change_table :va_rules, atomic_switch: true do |tbl|
      tbl.remove_index([:account_id, :rule_type, :position], 'index_va_rules_on_account_id_rule_type_and_position')
    end
  end
end

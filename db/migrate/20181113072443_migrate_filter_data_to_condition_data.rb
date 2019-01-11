class MigrateFilterDataToConditionData < ActiveRecord::Migration
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end
  
  def up
    failed_arr = []
    Sharding.run_on_all_shards do
      Account.find_each do |a|
        begin
          Account.reset_current_account
          a.make_current
          a.account_va_rules.where(rule_type: [VAConfig::BUSINESS_RULE, VAConfig::OBSERVER_RULE]).find_each do |rule|
            rule.migrate_filter_data
            rule.save
          end
        rescue Exception => e
          failed_arr.push(a.id)
        end
      end
    end
    failed_arr
  end

  def down
  end
end

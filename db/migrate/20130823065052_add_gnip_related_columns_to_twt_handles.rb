class AddGnipRelatedColumnsToTwtHandles < ActiveRecord::Migration
  shard :none
  def self.up
    Lhm.change_table :social_twitter_handles,:atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s ADD COLUMN ( rule_value text,
                                         rule_tag text,
                                         gnip_rule_state int default 0) " % m.name)
    end
  end

  def self.down
  	Lhm.change_table :social_twitter_handles,:atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s DROP COLUMN rule_value,
                            DROP COLUMN rule_tag,
                            DROP COLUMN gnip_rule_state " % m.name)
    end
  end
end

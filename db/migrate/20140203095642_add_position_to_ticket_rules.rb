class AddPositionToTicketRules < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :social_ticket_rules, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s ADD COLUMN position int unsigned " % m.name)
    end
  end
 
  def self.down
     Lhm.change_table :social_ticket_rules, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s DROP COLUMN position " % m.name)
    end
  end
end

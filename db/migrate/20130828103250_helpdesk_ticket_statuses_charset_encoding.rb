class HelpdeskTicketStatusesCharsetEncoding < ActiveRecord::Migration
  shard :none
  def self.up
    Lhm.change_table :helpdesk_ticket_statuses,:atomic_switch => true do |m|
      m.ddl("alter table %s CHARACTER SET utf8 COLLATE utf8_unicode_ci" % m.name)
    end
  end

  def self.down
  end
end

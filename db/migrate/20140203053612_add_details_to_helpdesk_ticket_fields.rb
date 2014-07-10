class AddDetailsToHelpdeskTicketFields < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :helpdesk_ticket_fields, :atomic_switch => true do |m|
      m.add_column :default, "tinyint(1) DEFAULT '0'"
      m.add_column :level, "bigint(20) DEFAULT NULL"
      m.add_column :parent_id, "bigint(20) DEFAULT NULL"
      m.add_column :prefered_ff_col, "varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL"
      m.add_column :import_id, "bigint(20) DEFAULT NULL"
    end
  end

  def self.down
    Lhm.change_table :helpdesk_ticket_fields, :atomic_switch => true do |m|
      m.remove_column :default
      m.remove_column :level
      m.remove_column :parent_id
      m.remove_column :prefered_ff_col
      m.remove_column :import_id
    end
  end
end
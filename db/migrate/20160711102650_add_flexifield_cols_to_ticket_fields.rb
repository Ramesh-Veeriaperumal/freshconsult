class AddFlexifieldColsToTicketFields < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def self.up
  	Lhm.change_table :helpdesk_ticket_fields, :atomic_switch => true do |m|
			m.ddl(" ALTER TABLE %s ADD COLUMN `ticket_form_id` bigint(20) ,
      						 ADD COLUMN	`column_name` varchar(255) DEFAULT NULL,
      						 ADD COLUMN `flexifield_coltype` varchar(255) DEFAULT NULL " % m.name)
      m.ddl(" ALTER TABLE %s ADD INDEX `index_tkt_flds_on_account_id_ticket_form_id_column_name`(account_id, ticket_form_id, column_name) " % m.name)
			
    end
  end

  def self.down
    Lhm.change_table :helpdesk_ticket_fields, :atomic_switch => true do |m|

    	m.ddl(" ALTER TABLE %s DROP INDEX `index_tkt_flds_on_account_id_ticket_form_id_column_name` " % m.name)

      m.ddl(" ALTER TABLE %s DROP COLUMN `ticket_form_id`,
      						           DROP COLUMN `column_name`,
      						           DROP COLUMN `flexifield_coltype` " % m.name)
    end
  end
end

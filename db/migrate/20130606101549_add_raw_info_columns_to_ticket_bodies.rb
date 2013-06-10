class AddRawInfoColumnsToTicketBodies < ActiveRecord::Migration
 shard :none
  def self.up
  	execute <<-SQL
  		ALTER TABLE helpdesk_ticket_bodies ADD (raw_text mediumtext,
							                    raw_html mediumtext, 
							                    meta_info mediumtext,
							                    version int)
  	SQL
  end

  def self.down
    execute <<-SQL
      ALTER TABLE helpdesk_ticket_bodies DROP COLUMN raw_text,
                                         DROP COLUMN raw_html,
                                         DROP COLUMN meta_info,  
                                         DROP COLUMN version
    SQL
  end
end

module PerformTablePartition
  
  PARTITION_TABLES = ["helpdesk_tickets","helpdesk_notes","users","helpdesk_ticket_states",
                      "flexifields","helpdesk_attachments","helpdesk_activities","survey_remarks",
                      "survey_handles","survey_results", "helpdesk_schema_less_tickets", 
                      "helpdesk_schema_less_notes","support_scores","helpdesk_dropboxes","helpdesk_external_notes",
                      "helpdesk_ticket_bodies","helpdesk_note_bodies","user_emails", 
                      "freshfone_calls" ]
  PARTITION_SIZE = 128
  
  PARTITION_COLUMN = "account_id"
  
  
  def self.add_auto_increment
    PARTITION_TABLES.each do |table_name|
      ActiveRecord::Base.connection.execute("alter table #{table_name} MODIFY COLUMN id bigint(20) NOT NULL AUTO_INCREMENT;")
    end
  end
  
  def self.process
    PARTITION_TABLES.each do |table_name|
      ActiveRecord::Base.connection.execute("alter table #{table_name} partition by hash(#{PARTITION_COLUMN}) partitions #{PARTITION_SIZE};")
    end
  end
  
  
  
end
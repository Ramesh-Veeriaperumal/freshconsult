module PerformTablePartition

  PARTITION_TABLES = ['helpdesk_tickets', 'helpdesk_notes', 'users', 'helpdesk_ticket_states',
                      'flexifields', 'helpdesk_attachments', 'helpdesk_activities', 'survey_remarks',
                      'survey_handles', 'survey_results', 'survey_result_data', 'helpdesk_schema_less_tickets',
                      'helpdesk_schema_less_notes', 'support_scores', 'helpdesk_dropboxes',
                      'helpdesk_external_notes', 'helpdesk_ticket_bodies', 'helpdesk_note_bodies', 'user_emails',
                      'freshfone_calls', 'archive_tickets', 'archive_notes', 'archive_ticket_associations',
                      'archive_note_associations', 'archive_childs', 'contact_notes', 'contact_note_bodies',
                      'company_notes', 'company_note_bodies', 'denormalized_flexifields', 'ticket_field_data'].freeze
  PARTITION_SIZE = 128

  PARTITION_COLUMN = "account_id"


  def self.add_auto_increment
    PARTITION_TABLES.each do |table_name|
      sql_array = ["alter table %s MODIFY COLUMN id bigint(20) NOT NULL AUTO_INCREMENT;", table_name]
      sql = ActiveRecord::Base.safe_send(:sanitize_sql_array, sql_array)
      ActiveRecord::Base.connection.execute(sql)
    end
  end

  def self.process
    PARTITION_TABLES.each do |table_name|
      sql_array = ["alter table %s partition by hash(%s) partitions %s;", table_name, PARTITION_COLUMN, PARTITION_SIZE]
      sql = ActiveRecord::Base.safe_send(:sanitize_sql_array, sql_array)
      ActiveRecord::Base.connection.execute(sql)
    end
  end
end


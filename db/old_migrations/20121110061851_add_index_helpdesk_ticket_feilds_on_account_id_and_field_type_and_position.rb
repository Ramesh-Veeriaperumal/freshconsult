class AddIndexHelpdeskTicketFeildsOnAccountIdAndFieldTypeAndPosition < ActiveRecord::Migration
  def self.up
  	#Index name is bit different here b'cz of too long
  	execute('CREATE INDEX index_tkt_flds_on_account_id_and_field_type_and_position ON helpdesk_ticket_fields (`account_id`,`field_type`,`position`)')
  end

  def self.down
  	execute('DROP INDEX index_tkt_flds_on_account_id_and_field_type_and_position ON helpdesk_ticket_fields')
  end
end

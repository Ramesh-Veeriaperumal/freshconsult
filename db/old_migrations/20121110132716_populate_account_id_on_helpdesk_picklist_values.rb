class PopulateAccountIdOnHelpdeskPicklistValues < ActiveRecord::Migration
  def self.up
  	
  	#For all ticket_fields related entries
  	execute <<-SQL
      UPDATE helpdesk_picklist_values picklist INNER JOIN helpdesk_ticket_fields htf 
      ON picklist.pickable_id=htf.id AND picklist.pickable_type='Helpdesk::TicketField' 
      SET picklist.account_id=htf.account_id
    SQL

    #For first level picklist values
    execute <<-SQL
      UPDATE helpdesk_picklist_values picklist1 INNER JOIN helpdesk_picklist_values picklist2 
      ON picklist1.pickable_id=picklist2.id AND picklist1.`pickable_type` = 'Helpdesk::PicklistValue' 
      AND picklist1.account_id IS NULL
      SET picklist1.account_id = picklist2.account_id 
    SQL

    #For second level picklist values
    execute <<-SQL
      UPDATE helpdesk_picklist_values picklist1 INNER JOIN helpdesk_picklist_values picklist2 
      ON picklist1.pickable_id=picklist2.id AND picklist1.`pickable_type` = 'Helpdesk::PicklistValue' 
      AND picklist1.account_id IS NULL
      SET picklist1.account_id = picklist2.account_id 
    SQL

  end

  def self.down
  	#setting to null
    execute <<-SQL
      UPDATE helpdesk_picklist_values SET account_id=NULL
    SQL
  end
end

class CreateTriggerForTicketStatuses < ActiveRecord::Migration
  def self.up
    execute <<-SQL
      CREATE TRIGGER add_custom_status_id before insert on helpdesk_ticket_statuses for each row 
      begin
       declare max_status_id integer;
       if new.status_id is null then
        select max(status_id) into  max_status_id from helpdesk_ticket_statuses where ticket_field_id = new.ticket_field_id;
        if max_status_id is null then
          set max_status_id = 1;
        end if;
        set new.status_id = max_status_id + 1; 
       end if; 
      end;
      SQL
  end

  def self.down
  end
end

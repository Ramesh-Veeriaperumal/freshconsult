module TriggerSql
  def self.sql_for_populating_ticket_display_id()
    #Current mysql doesn't have support to check the existence of a trigger while creating one.
    'create trigger add_ticket_display_id before insert on helpdesk_tickets for each row 
      begin
        declare display_id_to_set integer;
        select max(display_id) into display_id_to_set from helpdesk_tickets where account_id = new.account_id;
        if display_id_to_set is null then
          set new.display_id = 1;
        else
          set new.display_id = display_id_to_set + 1;
        end if;
      end;'
  end
end

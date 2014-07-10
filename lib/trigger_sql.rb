module TriggerSql
  def self.sql_for_populating_ticket_display_id()
    #Current mysql doesn't have support to check the existence of a trigger while creating one.
    'create trigger add_ticket_display_id before insert on helpdesk_tickets for each row 
      begin
       declare ticket_dis_id integer;
       declare max_dis_id integer;
       if new.display_id is null then
        select max(display_id) into  max_dis_id from helpdesk_tickets where account_id = new.account_id;
        select ticket_display_id into  ticket_dis_id from accounts where id = new.account_id;
        if max_dis_id is null then 
            set max_dis_id = 1;
        else
            set max_dis_id = max_dis_id + 1; 
        end if;
        if ticket_dis_id > max_dis_id then
         set new.display_id = ticket_dis_id;
        else
         set new.display_id = max_dis_id;
        end if;
       end if; 
      end;'
  end
  
  def self.sql_for_populating_custom_status_id()
    'create trigger add_custom_status_id before insert on helpdesk_ticket_statuses for each row 
      begin
       declare max_status_id integer;
       if new.status_id is null then
        select max(status_id) into  max_status_id from helpdesk_ticket_statuses where ticket_field_id = new.ticket_field_id;
        if max_status_id is null then
          set max_status_id = 1;
        end if;
        set new.status_id = max_status_id + 1; 
       end if;
      end;'
  end
end

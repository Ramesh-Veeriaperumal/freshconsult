class AddTicketDisplayTrigger < ActiveRecord::Migration
  def self.up
  execute "drop trigger add_ticket_display_id"
  
   execute "create trigger add_ticket_display_id before insert on helpdesk_tickets for each row 
      begin
        declare ticket_dis_id integer;
        select max(dis_ids.dis_id) into ticket_dis_id from ((select max(display_id) as dis_id from helpdesk_tickets where account_id = new.account_id) union (select ticket_display_id as dis_id from accounts where id = new.account_id)) dis_ids;
        set new.display_id = ticket_dis_id + 1;
      end;"
  
 
  
  
  end

  def self.down
	execute "drop trigger add_ticket_display_id"
	execute "create trigger add_ticket_display_id before insert on helpdesk_tickets for each row 
      begin
        declare display_id_to_set integer;
        select max(display_id) into display_id_to_set from helpdesk_tickets where account_id = new.account_id;
        if display_id_to_set is null then
          set new.display_id = 1;
        else
          set new.display_id = display_id_to_set + 1;
        end if;
      end;"
   
  
  end
end

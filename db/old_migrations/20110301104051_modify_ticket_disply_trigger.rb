class ModifyTicketDisplyTrigger < ActiveRecord::Migration
 def self.up
  execute "drop trigger add_ticket_display_id"
  
   execute "create trigger add_ticket_display_id before insert on helpdesk_tickets for each row 
      begin
        declare ticket_dis_id integer;
        declare max_dis_id integer;
        select max(display_id) into  max_dis_id from helpdesk_tickets where account_id = new.account_id;
        select ticket_display_id into  ticket_dis_id from accounts where id = new.account_id;
        set max_dis_id = max_dis_id + 1; 
        if ticket_dis_id > max_dis_id then
         set new.display_id = ticket_dis_id;
        else
         set new.display_id = max_dis_id;
        end if;
      end;"
  
 
  
  
  end

  def self.down
	execute "drop trigger add_ticket_display_id"
	
	execute "create trigger add_ticket_display_id before insert on helpdesk_tickets for each row 
      begin
        declare ticket_dis_id integer;
        declare max_dis_id integer;
        select max(display_id) into  max_dis_id from helpdesk_tickets where account_id = new.account_id;
        select ticket_display_id into  ticket_dis_id from accounts where id = new.account_id;
        if ticket_dis_id > max_dis_id then
         set new.display_id = ticket_dis_id + 1;
        else
         set new.display_id = max_dis_id + 1;
        end if;
      end;"
   
  
  end
  
  end

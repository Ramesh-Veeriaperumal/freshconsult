class ModifyTicketDispTrigger < ActiveRecord::Migration
  def self.up
    execute "drop trigger add_ticket_display_id"
    ActiveRecord::Base.connection.execute(TriggerSql.sql_for_populating_ticket_display_id)
  end

  def self.down
    execute "drop trigger add_ticket_display_id"
  
   execute "create trigger add_ticket_display_id before insert on helpdesk_tickets for each row 
      begin
        declare ticket_dis_id integer;
        declare max_dis_id integer;
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
      end;"
  
  end
end

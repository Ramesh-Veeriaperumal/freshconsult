module TriggerSql
  def self.sql_for_populating_ticket_display_id()
    #Current mysql doesn't have support to check the existence of a trigger while creating one.
    'create trigger add_ticket_display_id before insert on helpdesk_tickets for each row 
      begin
        declare ticket_dis_id integer;
        select max(dis_ids.dis_id) into ticket_dis_id from ((select max(display_id) as dis_id from helpdesk_tickets where account_id = new.account_id) union (select ticket_display_id as dis_id from accounts where id = new.account_id)) dis_ids;
        set new.display_id = ticket_dis_id + 1;
      end;'
  end
end

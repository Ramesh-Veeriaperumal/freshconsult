class InternationalizeActivitityData < ActiveRecord::Migration
  def self.up
    execute 'update helpdesk_activities set description="activities.tickets.conversation.note.long", 
            short_descr="activities.tickets.conversation.note.short" 
            where short_descr="{{user_path}} added a {{comment_path}}"'
            
    execute 'update helpdesk_activities set description="activities.tickets.priority_change.long", 
            short_descr="activities.tickets.priority_change.short" 
            where short_descr="{{user_path}} changed the priority to {{priority_name}}"'
            
    execute 'update helpdesk_activities set description="activities.tickets.status_change.long", 
            short_descr="activities.tickets.status_change.short" 
            where short_descr="{{user_path}} changed the status to {{status_name}}"'
            
    execute 'update helpdesk_activities set description="activities.solutions.new_solution.long", 
            short_descr="activities.solutions.new_solution.short" 
            where short_descr="{{user_path}} created the new solution"'
            
    execute 'update helpdesk_activities set description="activities.tickets.new_ticket.long", 
            short_descr="activities.tickets.new_ticket.short" 
            where short_descr="{{user_path}} created the ticket"'
            
    execute 'update helpdesk_activities set description="activities.tickets.execute_scenario.long", 
            short_descr="activities.tickets.execute_scenario.short" 
            where short_descr="{{user_path}} executed the scenario \'{{scenario_name}}\'"'
            
    execute 'update helpdesk_activities set description="activities.tickets.conversation.out_email.long", 
            short_descr="activities.tickets.conversation.out_email.short" 
            where short_descr="{{user_path}} has sent a {{reply_path}}"'
            
    execute 'update helpdesk_activities set description="activities.tickets.conversation.in_email.long", 
            short_descr="activities.tickets.conversation.in_email.short" 
            where short_descr="{{user_path}} sent an {{email_response_path}}"'
            
    execute 'update helpdesk_activities set description="activities.tickets.new_ticket.long", 
            short_descr="activities.tickets.new_ticket.short" 
            where short_descr="{{user_path}} submitted the ticket"'
            
    execute 'update helpdesk_activities set description="activities.tickets.conversation.out_email.long", 
            short_descr="activities.tickets.conversation.out_email.short" 
            where short_descr="{{user_path}}has sent a {{reply_path}}"'
            
    execute 'update helpdesk_activities set description="activities.tickets.assigned_to_nobody.long", 
            short_descr="activities.tickets.assigned_to_nobody.short" 
            where short_descr="Assigned to \'Nobody\' by {{user_path}}"'
            
    execute 'update helpdesk_activities set description="activities.tickets.assigned.long", 
            short_descr="activities.tickets.assigned.short" 
            where description="{{user_path}} assigned the ticket {{notable_path}} to {{responder_path}}"'
            
    execute 'update helpdesk_activities set description="activities.tickets.reassigned.long", 
            short_descr="activities.tickets.assigned.short" 
            where description="{{user_path}} reassigned the ticket {{notable_path}} to {{responder_path}}"'
  end

  def self.down
  end
end

module Import::Zen::Ticket
 
  ZENDESK_TICKET_TYPES = {0 => "No Type Set", 1 => "Question", 2 => "Incident", 3 => "Problem", 4 => "Task"}                          
  ZENDESK_TICKET_STATUS = {1 => 2,  2=> 3, 3=> 4, 4 =>5 }         

 class Attachment < Import::FdSax
    element :url
 end
  
 class CustomField < Import::FdSax
    element "ticket-field-id" , :as => :field_id
    element :value 
  end
  
  class Comment < Import::FdSax
     element "author-id" , :as => :user_id
     element "created-at" , :as => :created_at
     element "is-public" , :as => :public
     element  :value , :as => :body
     elements :attachment , :as => :attachments , :class => Attachment
  end
  
 class TicketProp < Import::FdSax
    element "nice-id", :as => :display_id
    element :subject
    element :description
    element "status-id" , :as => :status 
    element "created-at", :as => :created_at
    element "assignee-id", :as => :responder_id
    element "assigned-at" , :as => :assigned_at
    element "initially-assigned-at" , :as => :first_assigned_at
    element "solved-at" , :as => :resolved_at
    element "status-updated-at" , :as => :status_upated_at    
    element "due-date", :as => :due_by
    element "resolution-time" , :as => :resolution_time
    element "requester-id", :as => :requester_id
    element "priority-id" , :as => :priority_id
    element "ticket-type-id", :as => :ticket_type
    element "group-id" , :as => :group_id
    element "updated-at" , :as => :updated_at
    elements :comment , :as => :comments , :class =>Comment
    elements "ticket-field-entry" , :as => :custom_fields , :class => CustomField
    elements :attachment , :as => :attachments , :class => Attachment
end

def save_ticket ticket_xml
  ticket_prop = TicketProp.parse(ticket_xml)    
  requester = @current_account.all_users.find_by_import_id(ticket_prop.requester_id)
  return unless requester
  priority_id = ticket_prop.priority_id.to_i() unless ticket_prop.priority_id.blank?
  priority_id = 1 if priority_id < 1
  props = {:subject=> ticket_prop.subject,:description => ticket_prop.description,:requester_id => requester.id , 
                    :account_id => @current_account.id , :status =>ZENDESK_TICKET_STATUS[ticket_prop.status.to_i], :due_by => ticket_prop.updated_at.to_datetime(),
                    :ticket_type => ZENDESK_TICKET_TYPES[ticket_prop.ticket_type.to_i] , :created_at =>ticket_prop.created_at.to_datetime(),
                    :updated_at => ticket_prop.updated_at.to_datetime() , :import_id => ticket_prop.display_id , :priority => priority_id  }  
  
  ticket_exist = @current_account.tickets.find_by_import_id(ticket_prop.display_id.to_i())
  puts "Read ticket  with id: #{ticket_prop.display_id} and created time: #{ticket_prop.created_at} and exist:#{ticket_exist}"
  return if ticket_exist
  display_id_exist = @current_account.tickets.find_by_display_id(ticket_prop.display_id.to_i())         
  responder = @current_account.all_users.find_by_import_id(ticket_prop.responder_id) unless ticket_prop.responder_id.blank? 
  group = @current_account.groups.find_by_import_id(ticket_prop.group_id.to_i()) unless ticket_prop.group_id.blank?
  props.store(:display_id, ticket_prop.display_id) unless display_id_exist
  props.store(:responder_id , responder.id) if responder
  props.store(:group_id , group.id) if group
  
  @ticket = @current_account.tickets.new(props)            
  if @ticket.save
    ticket_state = {:assigned_at => ticket_prop.assigned_at , :created_at =>ticket_prop.created_at.to_datetime(), 
                          :updated_at => ticket_prop.updated_at.to_datetime() ,:first_assigned_at => ticket_prop.first_assigned_at }
    ticket_state.store(:resolved_at ,ticket_prop.status_upated_at.to_datetime() ) if ticket_prop.status.to_i >2
    ticket_state.store(:closed_at ,ticket_prop.status_upated_at.to_datetime() ) if ticket_prop.status.to_i >3
    ticket_state.store(:opened_at ,ticket_prop.status_upated_at.to_datetime() ) if ticket_prop.status.to_i == 1
    ticket_state.store(:pending_since ,ticket_prop.status_upated_at.to_datetime() ) if ticket_prop.status.to_i == 2
    @ticket.ticket_states.update_attributes(ticket_state)   
    ticket_post_process ticket_prop , @ticket  
  end
end

def ticket_post_process ticket_prop , ticket
  custom_hash ={}              
  ticket_prop.custom_fields.each do |custom_field|
    ff_def_entry = FlexifieldDefEntry.first(:conditions =>{:flexifield_def_id => @current_account.flexi_field_defs.first.id ,:import_id => custom_field.field_id.to_i()})
    custom_hash.store(ff_def_entry.flexifield_alias ,custom_field.value) unless ff_def_entry.blank? 
  end
  
  unless custom_hash.blank?      
    ticket.ff_def = @current_account.flexi_field_defs.first.id       
    ticket.assign_ff_values custom_hash    
  end
  #Attachment
  ticket_prop.attachments.each do |attachment|   
    Import::Attachment.new(ticket.id ,attachment.url, :ticket )
  end 
  ticket_prop.comments.each do |comment| 
    user = @current_account.all_users.find_by_import_id(comment.user_id)
    note_props = comment.to_hash.tap { |hs| hs.delete(:public) }.merge({:user_id =>user.id, :private => !comment.public ,:incoming =>user.customer?,
                                                                        :account_id => @current_account.id , :body =>comment.body,:deleted => false ,
                                                                        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] , :created_at =>comment.created_at.to_datetime()})
    @note = ticket.notes.build(note_props)
    @note.save
    comment.attachments.each do |attachment| 
      Import::Attachment.new(@note.id ,attachment.url, :note )
    end
  end
end

end
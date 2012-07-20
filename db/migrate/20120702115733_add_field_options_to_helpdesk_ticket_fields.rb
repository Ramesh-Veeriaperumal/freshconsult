class AddFieldOptionsToHelpdeskTicketFields < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_ticket_fields, :field_options, :text
    ticket_fields = Helpdesk::TicketField.find(:all , :conditions =>{:field_type => 'default_requester'})
  	ticket_fields.each do |field|
  		field.update_attributes(:field_options => {"portalcc"=> false, "portalcc_to"=>"company"})
    end
  end

  def self.down
    remove_column :helpdesk_ticket_fields, :field_options
  end
end

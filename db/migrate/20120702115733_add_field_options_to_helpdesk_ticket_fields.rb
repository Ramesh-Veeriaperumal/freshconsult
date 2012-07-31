class AddFieldOptionsToHelpdeskTicketFields < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_ticket_fields, :field_options, :text
    Account.all.each do |account|
        field = account.ticket_fields.find_by_field_type('default_requester')
        field.update_attributes(:field_options => {"portalcc"=> false, "portalcc_to"=>"company"})
    end
  end

  def self.down
    remove_column :helpdesk_ticket_fields, :field_options
  end
end

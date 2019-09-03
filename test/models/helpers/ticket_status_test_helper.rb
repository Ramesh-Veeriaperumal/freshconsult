module TicketStatusTestHelper
  def create_ticket_status(options = {})
    status_field = @account.ticket_fields.find_by_name('status')
    ticket_status_values = @account.ticket_status_values
    last_status_id = ticket_status_values.map(&:status_id).max
    last_position_id = ticket_status_values.map(&:position).max
    ticket_status = FactoryGirl.build(:ticket_status, account_id: @account.id,
                                                      name: options[:name] || Faker::Name.name,
                                                      customer_display_name: options[:customer_display_name] || Faker::Name.name,
                                                      stop_sla_timer: options[:stop_sla_timer] || 1,
                                                      position: last_position_id + 1,
                                                      status_id: last_status_id + 1,
                                                      ticket_field_id: status_field.id)
    ticket_status.save!
    ticket_status
  end
end

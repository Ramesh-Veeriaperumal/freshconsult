module Admin::Automation::CustomStatusHelper
  def supervisor_custom_status_name(name)
    status_id = name.split('_').last.to_i
    status_name = Helpdesk::TicketStatus.status_names_by_key(Account.current)[status_id]
    status_name = Account.current.ticket_statuses.find_by_status_id(status_id).name if status_name.blank?
    status_name = status_name.downcase.split(' ').join('_')
    "hours since #{status_name}"
  end
end

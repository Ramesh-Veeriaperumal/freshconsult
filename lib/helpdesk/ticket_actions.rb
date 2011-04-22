module Helpdesk::TicketActions
  
  def create_the_ticket(need_captcha = nil)
    @ticket = current_account.tickets.build(params[:helpdesk_ticket])
    set_default_values

    return false if need_captcha && !(current_user || verify_recaptcha(:model => @ticket, 
                                                        :message => "Captcha verification failed, try again!"))
    return false unless @ticket.save
    
    handle_attachments
    @ticket.create_activity(@ticket.requester, "{{user_path}} submitted a new ticket {{notable_path}}", {}, 
                                 "{{user_path}} submitted the ticket")
    if params[:meta]
      @ticket.notes.create(
        :body => params[:meta].map { |k, v| "#{k}: #{v}" }.join("\n"),
        :private => true,
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'],
        :account_id => current_account.id,
        :user_id => current_user && current_user.id
      )
    end
    @ticket
  end

  def set_default_values
    @ticket.status = TicketConstants::STATUS_KEYS_BY_TOKEN[:open] unless TicketConstants::STATUS_NAMES_BY_KEY.key?(@ticket.status)
    @ticket.source ||= TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal]
    @ticket.ticket_type ||= TicketConstants::TYPE_KEYS_BY_TOKEN[:how_to]
    @ticket.email ||= current_user && current_user.email
  end
  
  #handle_attachments part ideally should go to the ticket model. And, 'attachments' is a protected attribute, so 
  #we are getting the mass-assignment warning right now..
  def handle_attachments
    (params[:helpdesk_ticket][:attachments] || []).each do |a|
      @ticket.attachments.create(:content => a[:file], :description => a[:description], :account_id => @ticket.account_id)
    end
  end

end

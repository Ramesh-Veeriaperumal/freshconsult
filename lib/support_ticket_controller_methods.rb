module SupportTicketControllerMethods

  def show
    @ticket = Helpdesk::Ticket.find_by_param(params[:id], current_account)
    return if current_user && @ticket.requester_id == current_user.id
    return if permission?(:manage_tickets)
    return if params[:access_token] && @ticket.access_token == params[:access_token]
    redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
  end

  def new
    @ticket = Helpdesk::Ticket.new 
    if current_user
      #@ticket.name = current_user.name if current_user.respond_to?(:name)
      #@ticket.email = current_user.email if current_user.respond_to?(:email)
    end
  end

  def create
    @ticket = Helpdesk::Ticket.new(
      {
        :status => Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open],
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:web_form],
        :requester_id => current_user && current_user.id,
        :account_id => current_account.id
      }.merge(params[:helpdesk_ticket])
    )
    
    if (current_user || verify_recaptcha(:model => @ticket, :message => "Captcha verification failed, try again!")) && @ticket.save
      @ticket.notes.create(
        :body => params[:helpdesk_ticket][:description],
        :description => "raised the ticket",
        #:user_id => current_user && current_user.id,
        :user => @ticket.requester, #by Shan temp
        :account_id => current_account.id,
        :private => false,
        :incoming => true,
        :source => 1
      )
      Helpdesk::TicketNotifier.send_later(:deliver_autoreply, @ticket) if !@ticket.spam
      
      @ticket.create_activity(@ticket.requester, "{{user_path}} raised the ticket {{notable_path}}")

      if params[:meta]
        @ticket.notes.create(
          :body => params[:meta].map { |k, v| "#{k}: #{v}" }.join("\n"),
          :private => true,
          :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'],
          :account_id => current_account.id
        )
      end

      flash[:notice] = "Your request has been created and a copy has been sent to you via email."
      redirect_to redirect_url and return
    end

    render :action => :new
  end

end

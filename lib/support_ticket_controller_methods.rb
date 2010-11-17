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

    if @ticket.save
      @ticket.notes.create(
        :body => params[:helpdesk_ticket][:description],
        :user_id => current_user && current_user.id,
        :account_id => current_account.id,
        :private => false,
        :incoming => true,
        :source => 1
      )
      #Helpdesk::TicketNotifier.deliver_autoreply(@ticket) if !@ticket.spam #by Shan temp

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

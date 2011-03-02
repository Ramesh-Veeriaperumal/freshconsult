module SupportTicketControllerMethods

  def show
    @ticket = Helpdesk::Ticket.find_by_param(params[:id], current_account)
    return if current_user && @ticket.requester_id == current_user.id
    return if permission?(:manage_tickets)
    redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
  end

  def new
    @ticket = Helpdesk::Ticket.new 
    
    set_customizer
    
    @ticket
    
    if current_user
      #@ticket.name = current_user.name if current_user.respond_to?(:name)
      @ticket.email = current_user.email if current_user.respond_to?(:email)
    end
  end
  
 def set_customizer
    
     requester_view = (Helpdesk::FormCustomizer.first(:conditions =>{:account_id =>current_account.id})).requester_view
     
     logger.debug "requester_view : #{requester_view}"
    
    @ticket.customizer ||= Helpdesk::FormCustomizer.first(:conditions =>{:account_id =>current_account.id})
    
  end

  def create
    
    get_custom_fields
    
   # @ticket = Helpdesk::Ticket.new(
   #   {
   #    :status => Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open],
   #    :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:web_form],
   #    :requester_id => current_user && current_user.id,
   #    :account_id => current_account.id
   #   }.merge(params[:helpdesk_ticket])
   # )
    
    @ticket = Helpdesk::Ticket.new(params[:helpdesk_ticket])
    
    set_default_values
    
    logger.debug "TICKET PARAMS ARE :: #{@ticket.inspect}"
   
    
    if (current_user || verify_recaptcha(:model => @ticket, :message => "Captcha verification failed, try again!")) && @ticket.save!
      
      handle_custom_fields
      
      (params[:helpdesk_ticket][:attachments] || []).each do |a|
        @ticket.attachments.create(:content => a[:file], :description => a[:description], :account_id => @ticket.account_id)
      end
       
      @ticket.create_activity(@ticket.requester, "{{user_path}} submitted a new ticket {{notable_path}}", {}, 
                                   "{{user_path}} submitted the ticket")

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
    else
        set_customizer
        logger.debug "Error is #{@ticket.errors}"
        render :action => :new
    end

    #redirect_to :action => :new
  end
 
 def set_default_values
   
   @ticket.status = Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open]
   @ticket.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:portal]
   @ticket.requester_id = current_user && current_user.id
   @ticket.account_id = current_account.id
  
 end
 
 def get_custom_fields
    
     @flexi_fields = params[:helpdesk_ticket][:flexifields]
   
      unless params[:helpdesk_ticket][:flexifields].nil?
        params[:helpdesk_ticket].delete("flexifields")
      end
    
    logger.debug "get_custom_fiels #{@flexi_fields}"
    
  end
 
  
 def handle_custom_fields

   ff_def_id = FlexifieldDef.find_by_account_id(current_account.id).id
    
   @ticket.ff_def = ff_def_id
   
   unless @flexi_fields.nil?
     
    @ticket.assign_ff_values @flexi_fields
    
   end
  
 end

end

module Helpdesk::TicketActions
  
  def create_the_ticket(need_captcha = nil)
    @ticket = current_account.tickets.build(params[:helpdesk_ticket])
     set_default_values
    return false if need_captcha && !(current_user || verify_recaptcha(:model => @ticket, 
                                                        :message => "Captcha verification failed, try again!"))
    return false unless @ticket.save
    handle_attachments

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
    @ticket.source = TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal] if @ticket.source == 0
    @ticket.email ||= current_user && current_user.email
    @ticket.email_config_id ||= current_portal.product.id
  end
  
  #handle_attachments part ideally should go to the ticket model. And, 'attachments' is a protected attribute, so 
  #we are getting the mass-assignment warning right now..
  def handle_attachments
    (params[:helpdesk_ticket][:attachments] || []).each do |a|
      @ticket.attachments.create(:content => a[:resource], :description => a[:description], :account_id => @ticket.account_id)
    end
  end
  
  def split_the_ticket        
    create_ticket_from_note
    @note.destroy #delete the notes
    update_split_activity
    redirect_to @item
  end
  
  def assign_to_agent
    render :partial => "assign_agent"
  end
  
  def update_multiple_tickets
    render :partial => "update_multiple" 
  end

  def set_date_filter
   if !(params[:date_filter].to_i == TicketConstants::CREATED_BY_KEYS_BY_TOKEN[:custom_filter])
    params[:start_date] = params[:date_filter].to_i.days.ago.beginning_of_day.to_s(:db)
    params[:end_date] = Time.now.end_of_day.to_s(:db)
  else
    params[:start_date] = Date.parse(params[:start_date]).beginning_of_day.to_s(:db)
    params[:end_date] = Date.parse(params[:end_date]).end_of_day.to_s(:db)
   end
  end
  
  def configure_export
    flexi_fields = current_account.ticket_fields.custom_fields(:include => :flexifield_def_entry)
    csv_headers = Helpdesk::TicketModelExtension.csv_headers 
    #Product entry
    csv_headers = csv_headers + [ {:label => "Product", :value => "product_name", :selected => false} ] if current_account.has_multiple_products?
    csv_headers = csv_headers + flexi_fields.collect { |ff| { :label => ff.label, :value => ff.name, :selected => false} }

    flexi_fields.each do |flexi_field|
      if flexi_field.field_type == "nested_field"
        nested_flexi_fields = flexi_field.nested_ticket_fields(:include => :flexifield_def_entry)
        csv_headers = csv_headers + nested_flexi_fields.collect { |ff| { :label => ff.label, :value => ff.name, :selected => false} }
      end
    end

    render :partial => "configure_export", :locals => {:csv_headers => csv_headers }
  end
  
  def export_csv
    params[:wf_per_page] = "100000"
    params[:page] = "1"
    @items = current_account.tickets.created_at_inside(params[:start_date],params[:end_date]).filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')
    csv_hash = params[:export_fields]
    csv_string = FasterCSV.generate do |csv|
      headers = csv_hash.keys.sort
      csv << headers
       @items.each do |record|
        csv_data = []
        headers.each do |val|
          csv_data << record.send(csv_hash[val])
        end
        csv << csv_data
      end
    end
    send_data csv_string, 
            :type => 'text/csv; charset=utf-8; header=present', 
            :disposition => "attachment; filename=tickets.csv"
  end
  
  def component
    @ticket = current_account.tickets.find_by_id(params[:id])   
    render :partial => "helpdesk/tickets/components/#{params[:component]}", :locals => { :ticket => @ticket , :search_query =>params[:q] } 
  end
  
  def canned_reponse
    @ticket = current_account.tickets.find_by_id(params[:id])
    render :partial => "helpdesk/tickets/components/canned_responses"
  end
  
  def update_split_activity    
   @item.create_activity(current_user, 'activities.tickets.ticket_split.long',
            {'eval_args' => {'split_ticket_path' => ['split_ticket_path', 
            {'ticket_id' => @source_ticket.display_id, 'subject' => @source_ticket.subject}]}}, 'activities.tickets.ticket_split.short') 
                  
  end
  
  def create_ticket_from_note    
    @source_ticket = current_account.tickets.find_by_display_id(params[:id])
    @note = @source_ticket.notes.find(params[:note_id])   
    params[:helpdesk_ticket] = {:subject =>@source_ticket.subject ,
                                :description_html =>@note.body_html ,
                                :email => @note.user.email,
                                :priority =>@source_ticket.priority,
                                :group_id =>@source_ticket.group_id,
                                :email_config_id => @source_ticket.email_config_id,
                                :status =>@source_ticket.status,
                                :source =>@source_ticket.source,
                                :ticket_type =>@source_ticket.ticket_type,                             
                                
                               }  
    unless @note.tweet.nil?
      tweet_hash = {:twitter_id => @note.user.twitter_id,
                    :tweet_attributes => {:tweet_id => @note.tweet.tweet_id, 
                                          :account_id => current_account.id}}
      params[:helpdesk_ticket] = params[:helpdesk_ticket].merge(tweet_hash)
      @note.tweet.destroy
    end
    build_item
    if @item.save
      flash[:notice] = I18n.t(:'flash.general.create.success', :human_name => cname.humanize.downcase)
      move_attachments   
    else
      puts @item.errors.to_json
    end
    
  end
  ## Need to test in engineyard--also need to test zendesk import
  def move_attachments   
    @note.attachments.each do |attachment|      
      url = attachment.content.url.split('?')[0]
      @item.attachments.create(:content =>  RemoteFile.new(URI.encode(url)), :description => "", :account_id => @item.account_id)    
    end
  end
  
  def show_tickets_from_same_user
    @source_ticket = current_account.tickets.find_by_display_id(params[:id])    
    @items = @source_ticket.requester.tickets.find(:all,:conditions => [" id != ? and deleted = ?", @source_ticket.id, false], :order => :status)
    @items = @items.paginate(:page => params[:page], :per_page => 5) #or tickets from customer
    if params[:page]
      render :partial => "helpdesk/merge/same_user_tickets"
    else
      render :partial => "helpdesk/merge/merge"
    end      
  end
  
  def confirm_merge    
    @source_ticket = current_account.tickets.find_by_display_id(params[:id])
    @target_ticket = current_account.tickets.find_by_display_id(params[:target_id])    
    render :partial => "helpdesk/merge/merge_script"
  end
  
  def complete_merge    
    @source_ticket = current_account.tickets.find_by_display_id(params[:source][:ticket_id])
    @target_ticket = current_account.tickets.find_by_display_id(params[:target][:ticket_id])   
    handle_merge
    flash.now[:notice] = t(:'flash.tickets.merge.success')
    redirect_to @target_ticket
  end
  
  def handle_merge      
    add_note_to_target_ticket
    move_source_notes_to_target   
    add_note_to_source_ticket
    close_source_ticket 
    update_merge_activity  
  end
  
  def update_merge_activity    
    @source_ticket.create_activity(current_user, 'activities.tickets.ticket_merge.long',
            {'eval_args' => {'merge_ticket_path' => ['merge_ticket_path', 
            {'ticket_id' => @target_ticket.display_id, 'subject' => @target_ticket.subject}]}}, 'activities.tickets.ticket_merge.short') 
  end
  
  def move_source_notes_to_target
    @source_ticket.notes.each do |note|
      note.update_attribute(:notable_id, @target_ticket.id)
    end
  end
  
  def close_source_ticket
    @source_ticket.update_attribute(:status , Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:closed])
  end
  
  def add_note_to_source_ticket
      @soucre_note = @source_ticket.notes.create(
        :body => params[:source][:note],
        :private => params[:source][:is_private] || false,
        :source => params[:source][:is_private] ? Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] : Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
        :account_id => current_account.id,
        :user_id => current_user && current_user.id
      )
      
      if !@soucre_note.private
        Helpdesk::TicketNotifier.send_later(:deliver_reply, @source_ticket, @soucre_note , @source_ticket.reply_email,{:include_cc => true})
      end
  end
  
  def add_note_to_target_ticket
    @target_note = @target_ticket.notes.create(
        :body_html => params[:target][:note],
        :private => params[:target][:is_private] || false,
        :source => params[:target][:is_private] ? Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] : Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
        :account_id => current_account.id,
        :user_id => current_user && current_user.id
      )
      ## handling attachemnt..need to check this
     @source_ticket.attachments.each do |attachment|      
      url = attachment.content.url.split('?')[0]
      @target_note.attachments.create(:content =>  RemoteFile.new(URI.encode(url)), :description => "", :account_id => @target_note.account_id)    
    end
    if !@target_note.private
      Helpdesk::TicketNotifier.send_later(:deliver_reply, @target_ticket, @target_note , @target_ticket.reply_email,{:include_cc => true})
    end
  end
  
  def search_tweets
    @search_keys = (current_account.twitter_handles.first.search_keys) || [] 
    @search_keys
  end  
  
  def reply_twitter_handle query
    current_account.twitter_search_keys.find_by_search_query(query).twitter_handle.id
  end
   
   def decode_utf8_b64(string)
      URI.unescape(CGI::escape(Base64.decode64(string)))
   end
  
 
end

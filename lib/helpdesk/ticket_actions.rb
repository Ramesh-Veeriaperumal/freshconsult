module Helpdesk::TicketActions
  
  include Helpdesk::Ticketfields::TicketStatus
  include ExportCsvUtil
  
  def create_the_ticket(need_captcha = nil)
    cc_emails = validate_emails(params[:cc_emails])
    ticket_params = params[:helpdesk_ticket].merge(:cc_email => {:cc_emails => cc_emails || [] , :fwd_emails => []})
    @ticket = current_account.tickets.build(ticket_params)
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
    notify_cc_people cc_emails unless cc_emails.blank? 
    @ticket
    
  end

  def notify_cc_people cc_emails
      Helpdesk::TicketNotifier.send_later(:deliver_send_cc_email, @ticket , {:cc_emails => cc_emails})
  end
  def set_default_values
    @ticket.status = OPEN unless (Helpdesk::TicketStatus.status_names_by_key(current_account).key?(@ticket.status) or @ticket.ticket_status.try(:deleted?))
    @ticket.source = TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal] if @ticket.source == 0
    @ticket.email ||= current_user && current_user.email
    @ticket.product ||= current_portal.product
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

  def configure_export
    render :partial => "configure_export", :locals => {:csv_headers => export_fields }
  end
  
  def export_csv
    params[:wf_per_page] = "100000"
    params[:page] = "1"
    items = current_account.tickets.created_at_inside(params[:start_date],params[:end_date]).filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')
    csv_hash = params[:export_fields]
    export_data items, csv_hash
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
                                :product_id => @source_ticket.product_id,
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
    @source_ticket.update_attribute(:status , CLOSED)
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
  
   # Method used set the ticket.ids in params[:data_hash] based on tags.name
  def serialize_params_for_tags
    return if params[:data_hash].nil? 

    action_hash = params[:data_hash].kind_of?(Array) ? params[:data_hash] : 
      ActiveSupport::JSON.decode(params[:data_hash])
    
    action_hash.each_with_index do |filter, index|
      next if filter["value"].nil? || !filter["condition"].eql?("helpdesk_tags.name")
      value = current_account.tickets.permissible(current_user).with_tag_names(filter["value"].split(",")).join(",")
      action_hash[index]={ :condition => "helpdesk_tickets.id", :operator => "is_in", :value => value }
      break
    end
    
    params[:data_hash] = action_hash;
  end

   def validate_emails email_array
     parent = @item
     unless email_array.blank?
      if email_array.is_a? String
        email_array = email_array.split(/,|;/)
      end
      email_array.delete_if {|x| !valid_email?(x)}
      email_array = email_array.collect{|e| e.gsub(/\,/,"")}
      email_array = email_array.uniq
     end
   end
    
    def extract_email(email)
      email = $1 if email =~ /<(.+?)>/
      email
    end
    
    def valid_email?(email)
      email = extract_email(email)
      (email =~ /\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b/) ? true : false
    end

  
end

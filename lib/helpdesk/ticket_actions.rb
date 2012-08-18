module Helpdesk::TicketActions
  
  include Helpdesk::Ticketfields::TicketStatus
  include ParserUtil
  include ExportCsvUtil
  
  def create_the_ticket(need_captcha = nil)
    cc_emails = fetch_valid_emails(params[:cc_emails])
    ticket_params = params[:helpdesk_ticket].merge(:cc_email => {:cc_emails => cc_emails , :fwd_emails => []})
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
    index_filter =  current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).deserialize_from_params(params)
    sql_conditions = index_filter.sql_conditions
    sql_conditions[0].concat(%(and helpdesk_ticket_states.#{params[:ticket_state_filter]} 
                               between '#{params[:start_date]}' and '#{params[:end_date]}'
                              )
                            )
    all_joins = %( INNER JOIN helpdesk_ticket_states ON 
                   helpdesk_ticket_states.ticket_id = helpdesk_tickets.id AND 
                   helpdesk_tickets.account_id = helpdesk_ticket_states.account_id)
    csv_hash = params[:export_fields]
    headers = csv_hash.keys.sort
    csv_string = FasterCSV.generate do |csv|
      csv << headers
      current_account.tickets.find_in_batches(:conditions => sql_conditions, 
                                            :include => [:ticket_states, :ticket_status, :flexifield,
                                                         :responder, :requester],
                                            :joins => all_joins
                                           ) do |items|
        items.each do |record|
          csv_data = []
          headers.each do |val|
            csv_data << record.send(csv_hash[val])
          end
          csv << csv_data
        end
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
    pvt_note = params[:source][:is_private]
      @soucre_note = @source_ticket.notes.create(
        :body => params[:source][:note],
        :private => pvt_note || false,
        :source => pvt_note ? Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] : Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
        :account_id => current_account.id,
        :user_id => current_user && current_user.id,
        :from_email => @source_ticket.reply_email,
        :to_emails => pvt_note ? [] : @source_ticket.requester.email.to_a,
        :cc_emails => pvt_note ? [] : @source_ticket.cc_email_hash && @source_ticket.cc_email_hash[:cc_emails]
      )
      if !@soucre_note.private
        Helpdesk::TicketNotifier.send_later(:deliver_reply, @source_ticket, @soucre_note ,{:include_cc => true})
      end
  end
  
  def add_note_to_target_ticket
    target_pvt_note = params[:target][:is_private]
    @target_note = @target_ticket.notes.create(
        :body_html => params[:target][:note],
        :private => target_pvt_note || false,
        :source => target_pvt_note ? Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] : Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
        :account_id => current_account.id,
        :user_id => current_user && current_user.id,
        :from_email => @target_ticket.reply_email,
        :to_emails => target_pvt_note ? [] : @target_ticket.requester.email.to_a,
        :cc_emails => target_pvt_note ? [] : @target_ticket.cc_email_hash && @target_ticket.cc_email_hash[:cc_emails]
      )
      ## handling attachemnt..need to check this
     @source_ticket.attachments.each do |attachment|      
      url = attachment.content.url.split('?')[0]
      @target_note.attachments.create(:content =>  RemoteFile.new(URI.encode(url)), :description => "", :account_id => @target_note.account_id)    
    end
    if !@target_note.private
      Helpdesk::TicketNotifier.send_later(:deliver_reply, @target_ticket, @target_note , {:include_cc => true})
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

  def reply_to_conv
    render :partial => "/helpdesk/shared/reply_form", 
           :locals => { :id => "send-email", :cntid => "cnt-reply-#{@conv_id}", :conv_id => @conv_id,
           :note => [@ticket, Helpdesk::Note.new(:private => false)] }
  end

  def forward_conv
    render :partial => "/helpdesk/shared/forward_form", 
           :locals => { :id => "send-fwd-email", :cntid => "cnt-fwd-#{@conv_id}", :conv_id => @conv_id,
           :note => [@ticket, Helpdesk::Note.new(:private => true)] }
  end
  
end

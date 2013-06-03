# encoding: utf-8
module Helpdesk::TicketActions
  
  include Helpdesk::Ticketfields::TicketStatus
  include ParserUtil
  include ExportCsvUtil
  include Helpdesk::ToggleEmailNotification
  
  def create_the_ticket(need_captcha = nil)
    cc_emails = fetch_valid_emails(params[:cc_emails])
    ticket_params = params[:helpdesk_ticket].merge(:cc_email => {:cc_emails => cc_emails , :fwd_emails => []})
    @ticket = current_account.tickets.build(ticket_params)
    set_default_values
    return false if need_captcha && !(current_user || verify_recaptcha(:model => @ticket, 
                                                        :message => "Captcha verification failed, try again!"))
    build_ticket_attachments
    return false unless @ticket.save

    if params[:meta]
      @ticket.notes.create(
        :note_body_attributes => {:body => params[:meta].map { |k, v| "#{k}: #{v}" }.join("\n")},
        :private => true,
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'],
        :account_id => current_account.id,
        :user_id => current_user && current_user.id
      )
    end
    notify_cc_people cc_emails unless cc_emails.blank? 
    @ticket
    
  end

  def handle_screenshot_attachments
    decoded_file = Base64.decode64(params[:screenshot][:data])
    file = Tempfile.new([params[:screenshot][:name]]) 
    file.binmode
    file.write decoded_file
    attachment = @ticket.attachments.build(:content => file, :account_id => @ticket.account_id)
    file.close
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
  def build_ticket_attachments
    handle_screenshot_attachments unless params[:screenshot].blank?
      (params[:dropbox_url] || []).each do |urls|
        decoded_url =  URI.unescape(urls)
         @ticket.dropboxes.build(:url => decoded_url)
      end
    (params[:helpdesk_ticket][:attachments] || []).each do |a|
      @ticket.attachments.build(:content => a[:resource], :description => a[:description], :account_id => @ticket.account_id)
    end
  end
  
  def split_the_ticket        
    create_ticket_from_note
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
    # params[:later] = false

    #Handle export in Resque and send a mail to the current user, if the duration selected is more than DATE_RANGE_CSV (in days)
    # if(csv_date_range_in_days > TicketConstants::DATE_RANGE_CSV)
      # params[:later] = true
      Resque.enqueue(Helpdesk::TicketsExport, params)
      flash[:notice] = t("export_data.mail.info")
      redirect_to helpdesk_tickets_path
    # else
    #   csv_tickets_string = Helpdesk::TicketsExport.perform(params)
    #   send_data csv_tickets_string, 
    #           :type => 'text/csv; charset=utf-8; header=present', 
    #           :disposition => "attachment; filename=tickets.csv"
    # end
  end

  def component
    @ticket = current_account.tickets.find_by_id(params[:id])   
    unless @new_show_page
      render :partial => "helpdesk/tickets/components/#{params[:component]}", :locals => { :ticket => @ticket , :search_query =>params[:q] } 
    else
      render :partial => "helpdesk/tickets/show/#{params[:component]}", :locals => { :ticket => @ticket , :search_query =>params[:q] } 
    end
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
                                :email => @note.user.email,
                                :priority =>@source_ticket.priority,
                                :group_id =>@source_ticket.group_id,
                                :email_config_id => @source_ticket.email_config_id,
                                :product_id => @source_ticket.product_id,
                                :status =>@source_ticket.status,
                                :source =>@source_ticket.source,
                                :ticket_type =>@source_ticket.ticket_type,                             
                                :cc_email => {:fwd_emails=>[],
                                              :cc_emails => @note.cc_emails || []} ,
                                :ticket_body_attributes => { :description_html => @note.body_html}                            
                                
                               }  
    unless @note.tweet.nil?
      tweet_hash = {:twitter_id => @note.user.twitter_id,
                    :tweet_attributes => {:tweet_id => @note.tweet.tweet_id,
                                          :twitter_handle_id => @note.tweet.twitter_handle_id }}
      params[:helpdesk_ticket] = params[:helpdesk_ticket].merge(tweet_hash)
      @note.tweet.destroy
    end
    build_item
    move_attachments   
    move_dropboxes
    if @item.save
      @note.destroy
      flash[:notice] = I18n.t(:'flash.general.create.success', :human_name => cname.humanize.downcase)
    else
      puts @item.errors.to_json
    end
    
  end
  ## Need to test in engineyard--also need to test zendesk import
  def move_attachments   
    @note.attachments.each do |attachment|      
      url = attachment.authenticated_s3_get_url
      io = open(url) #Duplicate code from helpdesk_controller_methods. Refactor it!
      if io
        def io.original_filename; base_uri.path.split('/').last.gsub("%20"," "); end
      end
      @item.attachments.build(:content => io, :description => "", 
        :account_id => @item.account_id)
    end
  end

  def move_dropboxes #added to support dropbox while spliting tickets
    @note.dropboxes.each do |dropbox|
      @item.dropboxes.build(:url => dropbox.url)
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

  def reply_to_conv
    render :partial => "/helpdesk/shared/reply_form", 
           :locals => { :id => "send-email", :cntid => "cnt-reply-#{@conv_id}", :conv_id => @conv_id,
           :note => [@ticket, Helpdesk::Note.new(:private => false)] }
  end

  def forward_conv
    render :partial => (@new_show_page ? "/helpdesk/tickets/show/forward_form" : "/helpdesk/shared/forward_form"), 
           :locals => { :id => "send-fwd-email", :cntid => "cnt-fwd-#{@conv_id}", :conv_id => @conv_id,
           :note => [@ticket, Helpdesk::Note.new(:private => true)] }
  end
  
  def add_requester
    @user = current_account.users.new
    render :partial => "contacts/add_requester_form"
  end

  def full_paginate
    total_entries = params[:total_entries]
    if(total_entries.blank? || total_entries.to_i == 0)
      load_cached_ticket_filters
      load_ticket_filter
      @ticket_filter.deserialize_from_params(params)
      joins = @ticket_filter.get_joins(@ticket_filter.sql_conditions)
      options = { :joins => joins, :conditions => @ticket_filter.sql_conditions, :select => :id}
      options[:distinct] = true if @ticket_filter.sql_conditions[0].include?("helpdesk_tags.name")
      total_entries = current_account.tickets.permissible(current_user).count(options)
    end
    @ticket_count = total_entries.to_i
  end

  def clear_filter
    if params[:requester_id]
      params[:data_hash] = ActiveSupport::JSON.encode [{"operator"=>"is_in", 
                            "condition"=>"requester_id", "value"=> params[:requester_id] }]

      @ticket_filter.query_hash = [{"operator"=>"is_in", "condition"=>"requester_id", 
                                    "value"=> params[:requester_id] }]
                                    
      cache_filter_params
      @requester_id_param = params[:requester_id]
    end
  end
end

# encoding: utf-8
module Helpdesk::TicketActions
  
  include Helpdesk::Ticketfields::TicketStatus
  include ParserUtil
  include ExportCsvUtil
  include Helpdesk::ToggleEmailNotification
  include CloudFilesHelper
  include Facebook::Constants
  include Redis::RedisKeys

  def create_the_ticket(need_captcha = nil, skip_notifications = nil)

    cc_emails = fetch_valid_emails(params[:cc_emails])
    
    @ticket = current_account.tickets.build(params[:helpdesk_ticket])
    #Using .dup as otherwise its stored in reference format(&id0001 & *id001).
    @ticket.cc_email = {:cc_emails => cc_emails , :fwd_emails => [], :reply_cc => cc_emails.dup, :tkt_cc => cc_emails.dup}
    set_default_values
    # The below is_native_mobile? check is valid for iPhone app version 1.0.0 and Android app update 1.0.3 
    # Once substantial amout of users have upgraded from these version, we need to remove 
    # 1. json format in create method in lib/support_ticket_controller_method.rb
    # 2. is_native_mobile? check in create method in lib/helpdesk/ticket_actions.rb
    return false if need_captcha && !(current_user || is_native_mobile? ||verify_recaptcha(:model => @ticket, 
                                                        :message => "Captcha verification failed, try again!"))
    build_ticket_attachments
    @ticket.skip_notification = skip_notifications
    @ticket.meta_data = params[:meta] if params[:meta]
    
    return false unless @ticket.save_ticket

    notify_cc_people cc_emails unless cc_emails.blank? 
    @ticket
    
  end

  def handle_screenshot_attachments
    decoded_file = Base64.decode64(params[:screenshot][:data])
    file = Tempfile.new([params[:screenshot][:name], '.png']) 
    file.binmode
    file.write decoded_file
    attachment = @ticket.attachments.build(:content => file, :account_id => @ticket.account_id)
    file.close
  end

  def notify_cc_people cc_emails
    Helpdesk::TicketNotifier.send_later(:send_cc_email, @ticket , nil, {:cc_emails => cc_emails})
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
    attachment_builder(@ticket, params[:helpdesk_ticket][:attachments], params[:cloud_file_attachments] )
  end
  
  def split_the_ticket        
    create_ticket_from_note
    update_split_activities
    redirect_to @item
  end
  
  def assign_to_agent
    render :partial => "assign_agent"
  end
  
  def bulk_scenario
    render :partial => "helpdesk/tickets/show/scenarios", :locals => {:bulk_scenario => true} 
  end

  def update_multiple_tickets
    render :partial => "update_multiple" , :locals => { :select_all => false } 
  end

  def update_all_tickets
    render :partial => "update_multiple", :locals => { :select_all => true}  
  end

  def configure_export
    @csv_headers = export_fields 
    render :partial => "configure_export"
  end
  
  def export_csv
    # params[:later] = false

    #Handle export in Resque and send a mail to the current user, if the duration selected is more than DATE_RANGE_CSV (in days)
    # if(csv_date_range_in_days > TicketConstants::DATE_RANGE_CSV)
      # params[:later] = true
      remove_tickets_redis_key(export_redis_key)
      create_ticket_export_fields_list(params[:export_fields].keys)
      params[:portal_url] = main_portal? ? current_account.host : current_portal.portal_url
      Helpdesk::TicketsExportWorker.enqueue(params)
      flash[:notice] = t("export_data.ticket_export.info")
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
    render :partial => "helpdesk/tickets/show/#{params[:component]}", :locals => { :ticket => @ticket , :search_query =>params[:q] } 
  end
  
  def update_split_activities
   @item.create_activity(current_user, 'activities.tickets.ticket_split.long',
            {'eval_args' => {'split_ticket_path' => ['split_ticket_path', 
            {'ticket_id' => @source_ticket.display_id, 'subject' => @source_ticket.subject}]}}, 'activities.tickets.ticket_split.short') 

   @source_ticket.create_activity(current_user, 'activities.tickets.note_split.long',
            {'eval_args' => {'split_ticket_path' => ['split_ticket_path',
            {'ticket_id' => @item.display_id, 'subject' => @item.subject}]}}, 'activities.tickets.note_split.short')
                  
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
      tweet_hash = {  :twitter_id => @note.user.twitter_id,
                      :tweet_attributes => {
                        :tweet_id => @note.tweet.tweet_id,
                        :twitter_handle_id => @note.tweet.twitter_handle_id,
                        :tweet_type => @note.tweet.tweet_type.to_s,
                        :stream_id => @note.tweet.stream_id 
                      }
                   }
      params[:helpdesk_ticket] = params[:helpdesk_ticket].merge(tweet_hash)
      @note.tweet.destroy
    end
    
    unless @note.fb_post.nil?
      @child_fb_note_ids = @note.fb_post.child_ids
      fb_post_hash = {  :facebook_id => @note.user.fb_profile_id,
                        :fb_post_attributes => {
                          :post_id => @note.fb_post.post_id,
                          :facebook_page_id => @note.fb_post.facebook_page_id,
                          :account_id => @note.fb_post.account_id,
                          :parent_id => nil,
                          :post_attributes => {
                            :can_comment => true,
                            :post_type   => POST_TYPE_CODE[:comment]
                          }
                       }
                    }
      params[:helpdesk_ticket][:created_at] = @note.created_at
      params[:helpdesk_ticket] = params[:helpdesk_ticket].merge(fb_post_hash)
      @note.fb_post.destroy
    end    
    
    build_item 
    
    move_cloud_files
    if @item.save_ticket
      move_attachments
      @note.remove_activity
      @note.destroy
      Social::FbSplitTickets.perform_async({  :user_id => current_user.id,
                                              :child_fb_post_ids => @child_fb_note_ids,
                                              :comment_ticket_id => @item.id,
                                              :source_ticket_id  => @source_ticket.id}) if @item.fb_post
      flash[:notice] = I18n.t(:'flash.general.create.success', :human_name => cname.humanize.downcase)
    else
      puts @item.errors.to_json
    end
    
  end

  
  ## Need to test in engineyard--also need to test zendesk import
  def move_attachments   
    @note.attachments.update_all({:attachable_type =>"Helpdesk::Ticket" , :attachable_id => @item.id})
    @note.inline_attachments.update_all({:attachable_type =>"Inline" , :attachable_id => @item.id})
  end

  def move_cloud_files #added to support cloud_file while spliting tickets
    @note.cloud_files.each do |cloud_file|
      @item.cloud_files.build(:url => cloud_file.url,:filename => cloud_file.filename, 
        :application_id => cloud_file.application_id)
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
    render :partial=> "/helpdesk/tickets/show/form_layout",
            :locals => {:params => { :id => "send-fwd-email", :cntid => "cnt-fwd-#{@conv_id}", :conv_id => @conv_id,
                                :note => [@ticket, Helpdesk::Note.new(:private => true)] }, 
                        :page => "forward_form"
                        }
  end


  def reply_to_forward
    respond_to do |format|            
            format.nmobile {
              render :json => {:quote => quoted_text(@note)}
            }
            format.html {
                render(  :partial => '/helpdesk/tickets/show/form_layout', 
                :locals => {:params => {  :id => 'send-email', 
                              :cntid => "cnt-reply-fwd-#{@conv_id}", 
                              :note => [@ticket, Helpdesk::Note.new(:private => true)], 
                              :conv_id => @conv_id}, 
                            :page => "reply_to_forward"}
                            )
            }            
    end 
 
  end
  
  def add_requester
    @user = current_account.users.new
    @user.user_emails.build({:primary_role => true})
    render :partial => "contacts/add_requester_form"
  end

  def full_paginate
    unless current_account.features_included?(:no_list_view_count_query)
      total_entries = params[:total_entries]
      if(total_entries.blank? || total_entries.to_i == 0)
        load_cached_ticket_filters
        load_ticket_filter
        db_type = get_db_type(params)
        Sharding.send(db_type) do
          @ticket_filter.deserialize_from_params(params)
          if Account.current.launched?(:es_count_reads)
            total_entries = Search::Filters::Docs.new(@ticket_filter.query_hash).count(Helpdesk::Ticket)
          else
            joins = @ticket_filter.get_joins(@ticket_filter.sql_conditions)
            joins[0].concat(@ticket_filter.states_join) if @ticket_filter.sql_conditions[0].include?("helpdesk_ticket_states")
            options = { :joins => joins, :conditions => @ticket_filter.sql_conditions}
            if @ticket_filter.sql_conditions[0].include?("helpdesk_tags.name")
              options[:distinct] = true 
              options[:select] = :id
            end
            total_entries = current_account.tickets.permissible(current_user).count(options)
          end
        end
      end
      @ticket_count = total_entries.to_i
    else
      load_cached_ticket_filters
      render 'no_paginate' 
    end
  end

  def sort_by_response? 
    params[:wf_order].to_sym.eql?(:requester_responded_at) || params[:wf_order].to_sym.eql?(:agent_responded_at)
  end

  def get_db_type(params)
    ((params[:wf_order] && sort_by_response?) || current_account.slave_queries?) ? :run_on_slave : :run_on_master
  end

  def get_tag_name
    if params[:tag_id].present?
    params[:tag_name] = Helpdesk::Tag.find(params[:tag_id]).name
    end

  end

  def clear_filter
    if params[:requester_id]
      params[:data_hash] = ActiveSupport::JSON.encode [{"operator"=>"is_in", 
                            "condition"=>"requester_id", "value"=> params[:requester_id] }]

      @ticket_filter.query_hash = [{"operator"=>"is_in", "condition"=>"requester_id", 
                                    "value"=> params[:requester_id] }]
                                    
      cache_filter_params
      @requester_id_param = params[:requester_id]
    elsif params[:tag_name]
      params[:data_hash] = ActiveSupport::JSON.encode [{"operator"=>"is_in",
                                                        "condition"=>"helpdesk_tags.name", "value"=> params[:tag_name] }]

      @ticket_filter.query_hash = [{"operator"=>"is_in",
                                    "condition"=>"helpdesk_tags.name", "value"=> params[:tag_name] }]

      cache_filter_params
    elsif params[:company_id]
      params[:data_hash] = ActiveSupport::JSON.encode [{"operator"=>"is_in", 
                            "condition"=>"owner_id", "value"=> params[:company_id] }]
      
      @ticket_filter.query_hash = [{"operator"=>"is_in", "condition"=>"owner_id", 
                                    "value"=> params[:company_id] }]
      cache_filter_params
    end
  end

  def set_default_filter
    params[:filter_name] = "all_tickets" if params[:filter_name].blank? && params[:filter_key].blank? && params[:data_hash].blank?
    # When there is no data hash sent selecting all_tickets instead of new_and_my_open
  end

  private

  def create_ticket_export_fields_list(list)
    set_tickets_redis_lpush(export_redis_key, list) if list.any?
  end

  def export_redis_key
    EXPORT_TICKET_FIELDS % {:account_id => current_account.id, :user_id => current_user.id, :session_id => request.session_options[:id]}
  end
end

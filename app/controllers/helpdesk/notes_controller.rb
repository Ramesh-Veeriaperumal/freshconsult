class Helpdesk::NotesController < ApplicationController
  
  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :load_parent_ticket_or_issue
  
  include HelpdeskControllerMethods
  include ParserUtil
  
  before_filter :validate_attachment_size , :validate_fwd_to_email, :only =>[:create]
  before_filter :set_mobile, :prepare_mobile_note, :only => [:create]
    
  uses_tiny_mce :options => Helpdesk::TICKET_EDITOR

  def index
    @notes = @parent.conversation(params[:page])
    if request.xhr?
      render(:partial => "helpdesk/tickets/note", :collection => @notes)
    end    
  end
  
  def create  
    if @item.save
      if params[:post_forums]
        @topic = Topic.find_by_id_and_account_id(@parent.ticket_topic.topic_id,current_account.id)
        if !@topic.locked?
          @post  = @topic.posts.build(:body_html => params[:helpdesk_note][:body])
          @post.user = current_user
          @post.account_id = current_account.id
          @post.save!
        end
      end

      begin
        create_article if email_reply?
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
  
      post_persist
    else
      create_error
    end
  end
  
  def edit
    render :partial => "edit_note"
  end

  protected
    def scoper
      @parent.notes
    end

    def item_url
      if @parent.is_a?(Helpdesk::Ticket) && !params[:page].nil?
        helpdesk_ticket_path({:id=> @parent.display_id, :page =>  params[:page]})
      else
        @parent
      end
    end
    
    def email_reply?
      @item.source.eql?(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"])
    end
    
    def create_article
      kbase_email = current_account.kbase_email
      if ((params[:bcc_emails] && params[:bcc_emails].include?(kbase_email)) || (params[:cc_emails] && params[:cc_emails].include?(kbase_email)))
        params[:bcc_emails].delete(kbase_email)
        params[:cc_emails].delete(kbase_email)
        
        body_html = params[:helpdesk_note][:body_html]
        attachments = params[:helpdesk_note][:attachments]
        Helpdesk::KbaseArticles.create_article_from_note(current_account, current_user, @parent.subject, body_html, attachments)
      end
    end

    def process_item
      Thread.current[:notifications] = current_account.email_notifications
      if @parent.is_a? Helpdesk::Ticket
        if @item.email_conversation?
          send_reply_email
          @item.create_fwd_note_activity(params[:to_emails]) if @item.fwd_email?
        end
        if tweet?
          twt_type = params[:tweet_type] || :mention.to_s
          twt = send("send_tweet_as_#{twt_type}")
          @item.create_tweet({:tweet_id => twt.id, :account_id => current_account.id})
        elsif facebook?  
            send_facebook_reply  
        end
        @parent.responder ||= current_user 
        unless params[:ticket_status].blank?
          Thread.current[:notifications][EmailNotification::TICKET_RESOLVED][:requester_notification] = false
          @parent.status = Helpdesk::TicketStatus.status_keys_by_name(current_account)[I18n.t(params[:ticket_status])]
        end
        unless params[:notify_emails].blank?
          notify_array = validate_emails(params[:notify_emails])
          Helpdesk::TicketNotifier.send_later(:deliver_notify_comment, @parent, @item ,@parent.friendly_reply_email,{:notify_emails =>notify_array}) unless notify_array.blank? 
        end
        
      end

      if @parent.is_a? Helpdesk::Issue
        unless @item.private
          @parent.tickets.each do |t|
            t.notes << (c = @item.clone)
            Helpdesk::TicketNotifier.deliver_reply(t, c, reply_email)
          end
        end
        @parent.owner ||= current_user  if @parent.respond_to?(:owner)
      end
      @parent.save
      Thread.current[:notifications] = nil
    end
    
    def tweet?
      (!@parent.tweet.nil?) and (!params[:tweet].blank?)  and (params[:tweet].eql?("true")) 
    end
    
    def add_cc_email
      cc_email_hash_value = @parent.cc_email_hash # cc_email_hash value can be either nil or hash
      if cc_email_hash_value.nil?
        cc_email_hash_value = {:cc_emails => [], :fwd_emails => []}
      end
      if @item.fwd_email?
        params[:to_emails] = fetch_valid_emails params[:to_emails]
        params[:fwd_cc_emails] = fetch_valid_emails params[:fwd_cc_emails]
        params[:bcc_emails] = fetch_valid_emails params[:bcc_emails]
        fwd_emails = params[:to_emails] | params[:fwd_cc_emails] | params[:bcc_emails] | cc_email_hash_value[:fwd_emails]
        fwd_emails.delete_if {|email| (email == @parent.requester.email)}
        cc_email_hash_value[:fwd_emails]  = fwd_emails
      else
        cc_array = validate_emails params[:cc_emails]
        cc_array = cc_array.compact unless cc_array.nil?
        cc_array ||= []
        cc_email_hash_value[:cc_emails] = cc_array.uniq
      end
      @parent.update_attribute(:cc_email, cc_email_hash_value)      
   end

  def send_facebook_reply
    
    if @parent.is_fb_message?
      fb_reply = add_facebook_reply
      unless fb_reply.blank?
        fb_reply.symbolize_keys!
        @item.create_fb_post({:post_id => fb_reply[:id], :facebook_page_id =>@parent.fb_post.facebook_page_id ,:account_id => current_account.id,
                              :thread_id =>@parent.fb_post.thread_id , :msg_type =>'dm'})
      end
    else
      fb_comment = add_facebook_comment
      unless fb_comment.blank?
        fb_comment.symbolize_keys!
        @item.create_fb_post({:post_id => fb_comment[:id], :facebook_page_id =>@parent.fb_post.facebook_page_id ,:account_id => current_account.id})
      end
    end
    
  end
   
  def fetch_valid_emails email_array
    unless email_array.blank?
      email_array = email_array.collect {|email| email.scan(VALID_EMAIL_REGEX).uniq[0].strip}.compact
      email_array = email_array.uniq
    else
      email_array = []
    end
  end

   def validate_emails email_array
     unless email_array.blank?
      if email_array.is_a? String
        email_array = email_array.split(/,|;/)
      end
        email_array.delete_if {|x| (extract_email(x) == @parent.requester.email or !(valid_email?(x))) }
        email_array = email_array.collect{|e| (e.gsub(/\,/,"")).strip}
        email_array = email_array.uniq
     end
   end
    
    def extract_email(email)
      email = $1 if email =~ /<(.+?)>/
      email
    end
    
    def valid_email?(email)
      email = extract_email(email)
      (email =~ VALID_EMAIL_REGEX) ? true : false
    end

    def send_reply_email      
      reply_email = params[:reply_email][:id] unless params[:reply_email].nil?
      reply_email = current_account.primary_email_config.reply_email if reply_email.blank?
      add_cc_email     
      if @item.fwd_email?
        Helpdesk::TicketNotifier.send_later(:deliver_forward, @parent, @item , reply_email,{:bcc_emails => params[:bcc_emails],
                :to_emails => params[:to_emails], :fwd_cc_emails => params[:fwd_cc_emails]})
        flash[:notice] = t(:'fwd_success_msg')
      else        
        Helpdesk::TicketNotifier.send_later(:deliver_reply, @parent, @item , reply_email,{:include_cc => params[:include_cc] , 
                :bcc_emails =>validate_emails(params[:bcc_emails]),
                :send_survey => ((!params[:send_survey].blank? && params[:send_survey].to_i == 1) ? true : false)})
        flash[:notice] = t(:'flash.tickets.reply.success')
      end
    end

    def create_error
      redirect_to @parent
    end
    
    def send_tweet_as_mention
      reply_twitter = current_account.twitter_handles.find(params[:twitter_handle])
      unless reply_twitter.nil?
       begin
        @wrapper = TwitterWrapper.new reply_twitter
        twitter = @wrapper.get_twitter
        latest_comment = @parent.notes.latest_twitter_comment.first
        status_id = latest_comment.nil? ? @parent.tweet.tweet_id : latest_comment.tweet.tweet_id
        twitter.update(validate_tweet(@item.body), {:in_reply_to_status_id => status_id})
       rescue
         flash.now[:notice] = t('twitter.not_authorized')
       end
      end
  end
  
  
  def send_tweet_as_dm
     logger.debug "Called  send_tweet_as_dm send_tweet_as_dm "
      reply_twitter = current_account.twitter_handles.find(params[:twitter_handle])
      unless reply_twitter.nil?
       begin
        @wrapper = TwitterWrapper.new reply_twitter
        twitter = @wrapper.get_twitter
        latest_comment = @parent.notes.latest_twitter_comment.first
        status_id = latest_comment.nil? ? @parent.tweet.tweet_id : latest_comment.tweet.tweet_id    
        req_twt_id = latest_comment.nil? ? @parent.requester.twitter_id : latest_comment.user.twitter_id
        resp = twitter.direct_message_create(req_twt_id, @item.body)
       rescue  
         flash.now[:notice] = t('twitter.not_authorized')
       end
      end
  end
  
    def facebook?
      (!@parent.fb_post.nil?) and (!params[:fb_post].blank?)  and (params[:fb_post].eql?("true")) 
  end
  
  def add_facebook_comment
    
      fb_page =  @parent.fb_post.facebook_page
    
      unless fb_page.nil?
       begin 
        @fb_client = FBClient.new fb_page,{:current_account => current_account}
        facebook_page = @fb_client.get_page
        post_id =  @parent.fb_post.post_id
        comment = facebook_page.put_comment(post_id, @item.body) 
      rescue => e
        fb_page.update_attributes({ :reauth_required => true, :last_error => e.message})
        flash[:notice] = e.message
        return nil
       end
      end
  end
  
  ##This method can be used to send reply to facebook pvt message
  ##
  def add_facebook_reply
    fb_page =  @parent.fb_post.facebook_page
    unless fb_page.blank?
       begin 
        @fb_client = FBClient.new fb_page,{:current_account => current_account}
        facebook_page = @fb_client.get_page
        thread_id =  @parent.fb_post.thread_id
        reply = facebook_page.put_object(thread_id , 'messages',:message => @item.body)
      rescue => e
        fb_page.update_attributes({ :reauth_required => true, :last_error => e.message})
        flash[:notice] = e.message
        return nil
       end
     end
  end
  
   def validate_attachment_size
    fetch_item_attachments if @item.fwd_email?
    total_size = (params[nscname][:attachments] || []).collect{|a| a[:resource].size}.sum
    if total_size > Helpdesk::Note::Max_Attachment_Size    
      flash[:notice] = t('helpdesk.tickets.note.attachment_size.exceed')
      redirect_to :back  
    end
 end
 
 
  def validate_tweet tweet
   twitter_id = "@#{@parent.requester.twitter_id}" 
   return tweet if ( tweet[0,twitter_id.length] == twitter_id)
   twt_text = (twitter_id+" "+  tweet)
   twt_text = twt_text[0,Social::Tweet::LENGTH - 1] if twt_text.length > Social::Tweet::LENGTH
   return twt_text
  end

  def validate_fwd_to_email
    if(@item.fwd_email? and fetch_valid_emails(params[:to_emails]).blank?)
          flash[:error] = t('validate_fwd_to_email_msg')
          redirect_to item_url
    end
  end
  
end

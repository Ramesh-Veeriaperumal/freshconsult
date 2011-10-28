class Helpdesk::NotesController < ApplicationController
  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :load_parent_ticket_or_issue
  
  include HelpdeskControllerMethods
    
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
      @parent
    end

    def process_item
      Thread.current[:notifications] = current_account.email_notifications
      if @parent.is_a? Helpdesk::Ticket      
        send_reply_email if @item.source.eql?(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"])
        if tweet?
          twt = send_tweet
          @item.create_tweet({:tweet_id => twt.id, :account_id => current_account.id})
        elsif facebook?
          fb_comment = add_facebook_comment
          fb_comment.symbolize_keys!
          @item.create_fb_post({:post_id => fb_comment[:id], :facebook_page_id =>@parent.fb_post.facebook_page_id ,:account_id => current_account.id})
        end
        @parent.responder ||= current_user 
        unless params[:ticket_status].blank?
          Thread.current[:notifications][EmailNotification::TICKET_RESOLVED][:requester_notification] = false
          @parent.status = Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[params[:ticket_status].to_sym()]
        end
        unless params[:notify_emails].blank?
          notify_array = validate_emails(params[:notify_emails])
          Helpdesk::TicketNotifier.send_later(:deliver_notify_comment, @parent, @item ,@parent.reply_email,{:notify_emails =>notify_array}) unless notify_array.blank? 
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
     if !params[:include_cc].blank?# and !params[:cc_emails].blank?
      #cc_array = params[:cc_emails].split(',').collect
       cc_array = validate_emails params[:cc_emails]
       @parent.update_attribute(:cc_email, cc_array)    
     end
   end
   
   def validate_emails email_array
     unless email_array.blank?
     email_array.delete_if {|x| (extract_email(x) == @parent.requester.email or !(valid_email?(x))) }
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

    def send_reply_email
      reply_email = params[:reply_email][:id] unless params[:reply_email].nil?
      add_cc_email     
      Helpdesk::TicketNotifier.send_later(:deliver_reply, @parent, @item , reply_email,{:include_cc => params[:include_cc] , :bcc_emails =>validate_emails(params[:bcc_emails])})  
      flash[:notice] = t(:'flash.tickets.reply.success')
    end

    def create_error
      redirect_to @parent
    end
    
    def send_tweet
      reply_twitter = current_account.twitter_handles.find(params[:twitter_handle])
      unless reply_twitter.nil?
       begin
        @wrapper = TwitterWrapper.new reply_twitter
        twitter = @wrapper.get_twitter
        latest_comment = @parent.notes.latest_twitter_comment.first
        status_id = latest_comment.nil? ? @parent.tweet.tweet_id : latest_comment.tweet.tweet_id
        twitter.update(@item.body, {:in_reply_to_status_id => status_id})
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
        @fb_client = FBClient.new fb_page,{:current_account => current_account}
        facebook_page = @fb_client.get_page
        post_id =  @parent.fb_post.post_id
        comment = facebook_page.put_comment(post_id, @item.body) 
      end
  end
  

end

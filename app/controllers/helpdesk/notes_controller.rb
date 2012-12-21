class Helpdesk::NotesController < ApplicationController
  
  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :load_parent_ticket_or_issue
  
  include HelpdeskControllerMethods
  include ParserUtil
  include Helpdesk::Social::Facebook
  include Helpdesk::Social::Twitter
  
  before_filter :validate_attachment_size , :validate_fwd_to_email, :check_for_kbase_email, :set_default_source, :only =>[:create]
  before_filter :set_mobile, :prepare_mobile_note, :only => [:create]
    
  uses_tiny_mce :options => Helpdesk::TICKET_EDITOR

  def index

    if params[:since_id].present?
      @notes = @parent.conversation_since(params[:since_id])
    elsif params[:before_id].present?
      @notes = @parent.conversation_before(params[:before_id])
    else
      @notes = @parent.conversation(params[:page])
    end
    
    if request.xhr?
      unless params[:v].blank? or params[:v] != '2'
        @ticket_notes = @notes.reverse
        render :partial => "helpdesk/tickets/show/conversations"
      else
        render(:partial => "helpdesk/tickets/note", :collection => @notes)
      end
    else 
      options = {}
      options.merge!({:human=>true}) if(!params[:human].blank? && params[:human].to_s.eql?("true"))  #to avoid unneccesary queries to users
      respond_to do |format|
        format.xml do
         render :xml => @notes.to_xml(options) 
        end
        format.json do
          render :json => @notes.to_json(options)
        end
      end
    end    
  end

  def since
    @notes = @parent.notes.newest_first.since(params[:last_note])
    render(:partial => "helpdesk/tickets/show/note", :collection => @notes.reverse) 
  end

  def since
    @notes = @parent.notes.newest_first.since(params[:last_note])
    render(:partial => "helpdesk/tickets/show/note", :collection => @notes.reverse) 
  end

  
  def create  
    build_attachments @item, :helpdesk_note
    if @item.save
      if params[:post_forums]
        @topic = Topic.find_by_id_and_account_id(@parent.ticket_topic.topic_id,current_account.id)
        if !@topic.locked?
          @post  = @topic.posts.build(:body_html => params[:helpdesk_note][:body_html])
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
  

      if request.xhr? || params[:xhr].eql?('true')
        puts "XHR REQUEST :::: ----"
        render :xml => {:success => true}.to_xml
      else
        post_persist
      end

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
      if @kbase_email_exists
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
          @item.create_fwd_note_activity(params[:helpdesk_note][:to_emails]) if @item.fwd_email?
        end
        if tweet?
          twt_type = params[:tweet_type] || :mention.to_s
          if  send("send_tweet_as_#{twt_type}")
            flash[:notice] = t(:'flash.tickets.reply.success') 
          else
            flash.now[:notice] = t('twitter.not_authorized')
          end
        elsif facebook?  
          send_facebook_reply  
        end
        @parent.responder ||= @item.user unless @item.user.customer? 
        unless params[:ticket_status].blank?
          Thread.current[:notifications][EmailNotification::TICKET_RESOLVED][:requester_notification] = false
          @parent.status = Helpdesk::TicketStatus.status_keys_by_name(current_account)[I18n.t(params[:ticket_status])]
        end
        if @item.note? and !params[:helpdesk_note][:to_emails].blank?
          notify_array = validate_emails(params[:helpdesk_note][:to_emails])
          Helpdesk::TicketNotifier.send_later(:deliver_notify_comment, @parent, @item ,@parent.friendly_reply_email,{:notify_emails =>notify_array}) unless notify_array.blank? 
        end
      end

      if @parent.is_a? Helpdesk::Issue
        unless @item.private
          @parent.tickets.each do |t|
            t.notes << (c = @item.clone)
            Helpdesk::TicketNotifier.deliver_reply(t, c)
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
      cc_email_hash_value = @parent.cc_email_hash.nil? ? {:cc_emails => [], :fwd_emails => []} : @parent.cc_email_hash
      if @item.fwd_email?
        fwd_emails = @item.to_emails | @item.cc_emails | @item.bcc_emails | cc_email_hash_value[:fwd_emails]
        fwd_emails.delete_if {|email| (email == @parent.requester.email)}
        cc_email_hash_value[:fwd_emails]  = fwd_emails
      else
        cc_emails = @item.cc_emails | cc_email_hash_value[:cc_emails]
        cc_emails.delete_if {|email| (email == @parent.requester.email)}
        cc_email_hash_value[:cc_emails] = cc_emails
      end
      @parent.update_attribute(:cc_email, cc_email_hash_value)      
    end

    def send_reply_email      
      add_cc_email     
      if @item.fwd_email?
        Helpdesk::TicketNotifier.send_later(:deliver_forward, @parent, @item)
        flash[:notice] = t(:'fwd_success_msg') unless params[:xhr] == 'true'
      elsif @item.to_emails.present? or @item.cc_emails.present? or @item.bcc_emails.present?
        Helpdesk::TicketNotifier.send_later(:deliver_reply, @parent, @item, {:include_cc => params[:include_cc] , 
                :send_survey => ((!params[:send_survey].blank? && params[:send_survey].to_i == 1) ? true : false)})
        flash[:notice] = t(:'flash.tickets.reply.success') unless params[:xhr] == 'true'
      end
    end

    def create_error
      redirect_to @parent
    end
    
    def facebook?
      (!@parent.fb_post.nil?) and (!params[:fb_post].blank?)  and (params[:fb_post].eql?("true")) 
    end
  
  def validate_fwd_to_email
    if(@item.fwd_email? and fetch_valid_emails(params[:helpdesk_note][:to_emails]).blank?)
          flash[:error] = t('validate_fwd_to_email_msg')
          redirect_to item_url
    end
  end

  def check_for_kbase_email
    kbase_email = current_account.kbase_email
      if ((params[:helpdesk_note][:bcc_emails] && params[:helpdesk_note][:bcc_emails].include?(kbase_email)) || 
          (params[:helpdesk_note][:cc_emails] && params[:helpdesk_note][:cc_emails].include?(kbase_email)))
        @item.bcc_emails.delete(kbase_email)
        @item.cc_emails.delete(kbase_email)
        @kbase_email_exists = true
      end
  end

  def set_default_source
    @item.source = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"] if params[:helpdesk_note][:source].blank?
  end

  def after_restore_url
    :back
  end

end

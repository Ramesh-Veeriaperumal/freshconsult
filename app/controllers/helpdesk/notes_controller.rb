class Helpdesk::NotesController < ApplicationController
  
  before_filter :load_parent_ticket_or_issue

  helper 'helpdesk/tickets'
  
  include HelpdeskControllerMethods
  include ParserUtil
  include Conversations::Twitter
  include Facebook::TicketActions::Util
  include Helpdesk::Activities
  include Helpdesk::NotePropertiesMethods
  
  skip_before_filter :build_item, :only => [:create]
  alias :build_note :build_item
  before_filter :build_note_body_attributes, :build_note, :only => [:create]
  before_filter :verify_permission, :only => [:create, :index, :edit, :update, :destroy, :public_conversation]

  before_filter :validate_fwd_to_email, :check_for_kbase_email, :set_default_source, :only =>[:create]
  before_filter :fetch_item_attachments, :only =>[:create, :update]
  before_filter :set_mobile, :prepare_mobile_note, :only => [:create]
  before_filter :set_native_mobile, :only=>[:index , :destroy , :restore]
  before_filter :update_note_properties, :only=>[:update]
  before_filter :set_note_properties, :only=>[:destroy]
  def index

    if params[:since_id].present?
      @notes = @parent.conversation_since(params[:since_id])
    elsif params[:before_id].present?
      @notes = @parent.conversation_before(params[:before_id])
    else
      @notes = @parent.conversation(params[:page])
    end
    build_notes_last_modified_user_hash(@notes)
    if request.xhr?
      unless params[:v].blank? or params[:v] != '2'
        @ticket_notes = @notes.reverse
        @ticket_notes_total = @parent.conversation_count
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
        format.nmobile do
          array = []
          @notes.each do |note|
            array << note.to_mob_json
          end
          render :json => array
        end
      end
    end    
  end

  def create
    build_attachments @item, :helpdesk_note
    @item.send_survey = params[:send_survey]
    @item.send_survey = params[:include_surveymonkey_link]
    
    unless params[:ticket_status].blank?
      @item.notable.status = params[:ticket_status]
      Thread.current[:notifications] = current_account.email_notifications
      Thread.current[:notifications][EmailNotification::TICKET_RESOLVED][:requester_notification] = false
    end

    @item.quoted_text = params[:quoted_text].present? && params[:quoted_text] == 'true'
    @item.include_surveymonkey_link = params[:include_surveymonkey_link]

    if @item.save_note
      if params[:post_forums]
        @topic = Topic.find_by_id_and_account_id(@parent.ticket_topic.topic_id,current_account.id)
        if !@topic.locked?
          @post  = @topic.posts.build(:body_html => params[:helpdesk_note][:note_body_attributes][:body_html])
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

      if params[:showing] == 'activities'
        activity_records = @parent.activities.activity_since(params[:since_id])
        @activities = stacked_activities(@parent, activity_records.reverse)
      end
  
      post_persist
  
    else
      create_error
    end
  ensure
    Thread.current[:notifications] = nil
  end
  
  def edit
    @item.build_note_body(:body_html => @item.body_html,
        :body => @item.body) unless @item.note_body
    render :partial => "edit_note"
  end

  def update
    build_attachments @item, :helpdesk_note
    if @item.update_note_attributes(params[nscname])
      post_persist
      flash[:notice] = I18n.t(:'flash.general.update.success', :human_name => cname.humanize.downcase)
    else
      edit_error
    end
  end

  def agents_autocomplete
    @ticket = current_account.tickets.includes(:responder).find_by_display_id(params[:ticket_id])
    respond_to do |format|
      format.html { render :layout => false }
    end
  end

  def public_conversation
    @notes = @parent.conversation(nil, 5, [:note_old_body]).public
    respond_to do |format|
      format.html { render :layout => false }
    end
  end

  protected

    def build_note_body_attributes
      if params[:helpdesk_note][:body] || params[:helpdesk_note][:body_html]
        unless params[:helpdesk_note].has_key?(:note_body_attributes)
          note_body_hash = {:note_body_attributes => { :body => params[:helpdesk_note][:body],
                                  :body_html => params[:helpdesk_note][:body_html] }} 
          params[:helpdesk_note].merge!(note_body_hash).tap do |t| 
            t.delete(:body) if t[:body]
            t.delete(:body_html) if t[:body_html]
          end 
        end 
      end
    end

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
      @item.source.eql?(current_account.helpdesk_sources.note_source_keys_by_token["email"])
    end
    
    def create_article
      if @kbase_email_exists
        body_html = params[:helpdesk_note][:note_body_attributes][:body_html]
        attachments = params[:helpdesk_note][:attachments]
        Helpdesk::KbaseArticles.create_article_from_note(current_account, current_user, @parent.subject, body_html, attachments)
      end
    end

    def process_item
      if @parent.is_a? Helpdesk::Ticket
        if @item.email_conversation?
           if @item.fwd_email?
            flash[:notice] = t(:'fwd_success_msg')
           elsif @item.to_emails.present? or @item.cc_emails.present? or @item.bcc_emails.present?
            flash[:notice] = t(:'flash.tickets.reply.success')
           end
        end
        if tweet?
          twt_type = params[:tweet_type] || :mention.to_s
          @tweet_body = @note.body.strip
          twitter_handle_id = params[:twitter_handle_id]
          args = { ticket_id: @parent.id, note_id: @note.id, tweet_type: twt_type, twitter_handle_id: twitter_handle_id }
          Social::TwitterReplyWorker.perform_async(args)
          flash[:notice] = t(:'flash.tickets.reply.success')
        elsif facebook?
          send_facebook_reply
        end
      end
      Thread.current[:notifications] = nil
    end
    
    def tweet?
      (!@parent.tweet.nil?) and (!params[:tweet].blank?)  and (params[:tweet].eql?("true")) 
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
    @item.source = current_account.helpdesk_sources.note_source_keys_by_token["note"] if params[:helpdesk_note][:source].blank?
  end

  def after_restore_url
    :back
  end

  def verify_permission
    if (@parent && @parent.is_a?(Helpdesk::Ticket)) || (@item && @item.notable.is_a?(Helpdesk::Ticket))
      ticket = @parent || @item.notable
      verify_ticket_permission(ticket)
    end
  end

  def update_note_properties
    params[nscname][:last_modified_user_id] = current_user.id.to_s
    params[nscname][:last_modified_timestamp] = Time.now.utc
  end

  def set_note_properties
    @notes.each do |note|
      note.last_modified_user_id = current_user.id.to_s
      note.last_modified_timestamp = Time.now.utc
    end
  end
end

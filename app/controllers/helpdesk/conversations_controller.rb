class Helpdesk::ConversationsController < ApplicationController
  
  helper  Helpdesk::TicketsHelper#TODO-RAILS3
  
  before_filter :load_parent_ticket_or_issue
  
  include HelpdeskControllerMethods
  include ParserUtil
  include Conversations::Email
  include Conversations::Twitter
  include Facebook::TicketActions::Util
  include Helpdesk::Activities
  include Helpdesk::Permissions
  include Redis::RedisKeys
  include Redis::TicketsRedis
  include Social::Util
  helper Helpdesk::NotesHelper
  include Ecommerce::Ebay::ReplyHelper
  
  before_filter :build_note_body_attributes, :build_conversation, :except => [:full_text, :traffic_cop]
  before_filter :validate_fwd_to_email, :only => [:forward, :reply_to_forward]
  before_filter :check_for_kbase_email, :only => [:reply, :forward]
  before_filter :set_quoted_text, :only => :reply
  before_filter :set_default_source, :set_mobile, :prepare_mobile_note,
    :fetch_item_attachments, :set_native_mobile, :except => [:full_text, :traffic_cop]
  before_filter :set_ticket_status, :except => [:forward, :reply_to_forward, :traffic_cop]
  before_filter :load_item, :only => [:full_text]
  before_filter :verify_permission, :only => [:reply, :forward, :reply_to_forward, :note, :twitter, :facebook, :mobihelp, :ecommerce, :traffic_cop, :full_text]
  before_filter :traffic_cop_warning, :only => [:reply, :twitter, :facebook, :mobihelp, :ecommerce]
  before_filter :check_for_public_notes, :only => [:note]
  before_filter :validate_ecommerce_reply, :only => :ecommerce

  TICKET_REDIRECT_MAPPINGS = {
    "helpdesk_ticket_index" => "/helpdesk/tickets"
  }
    
  def reply
    build_attachments @item, :helpdesk_note
    @item.send_survey = params[:send_survey]
    @item.include_surveymonkey_link = params[:include_surveymonkey_link]
    if @item.save_note
      clear_saved_draft
      add_forum_post if params[:post_forums]
      note_to_kbase
      flash[:notice] = t(:'flash.tickets.reply.success')
      process_and_redirect
    else
      flash[:error] = @item.errors.full_messages.to_sentence 
      create_error(:reply)
    end
  end
  
  def forward
    build_attachments @item, :helpdesk_note
    if @item.save_note
      add_forum_post if params[:post_forums]
      note_to_kbase
      flash[:notice] = t(:'fwd_success_msg')
      process_and_redirect
    else
      flash[:error] = @item.errors.full_messages.to_sentence 
      create_error(:fwd)
    end
  end

  def reply_to_forward
    build_attachments @item, :helpdesk_note
    if @item.save_note
      add_forum_post if params[:post_forums]
      flash[:notice] = t(:'fwd_success_msg')
      process_and_redirect
    else
      flash[:error] = @item.errors.full_messages.to_sentence 
      create_error(:fwd)
    end

  end

  def note
    build_attachments @item, :helpdesk_note
    if @item.save_note
      flash_message "success"
      process_and_redirect
    else
      flash_message "failure"
      create_error(:note)
    end
  end

  def twitter
    tweet_text = params[:helpdesk_note][:note_body_attributes][:body].strip
    twt_type = Social::Tweet::TWEET_TYPES.rassoc(params[:tweet_type].to_sym) ? params[:tweet_type] : "mention"
    
    if twt_type.eql?"mention"
      error_message, @tweet_body = validate_tweet(tweet_text, "#{@parent.latest_twitter_comment_user}") 
    else
      error_message, @tweet_body = validate_tweet(tweet_text, nil, false) 
    end
    if error_message.blank?
      if @item.save_note 
        error_message, reply_twt = send("send_tweet_as_#{twt_type}")
        flash[:notice] = error_message.blank? ?  t(:'flash.tickets.reply.success') : error_message
        process_and_redirect
      else
        flash.now[:notice] = t(:'flash.tickets.reply.failure')
        create_error(:twitter)
      end
    else
      flash[:error] = error_message
      create_error(:twitter)
    end
  end

  def facebook
    if @item.save_note
      send_facebook_reply(params[:parent_post])
      process_and_redirect
    else
      # Flash here
      flash[:error] = "failure"
      create_error(:facebook)
    end
  end
  
  def mobihelp
    if @item.save_note
      flash[:notice] = t(:'flash.tickets.reply.success') 
      process_and_redirect
    else
      create_error
    end
  end

  def ecommerce
    ebay_reply 
  end

  def full_text
    render :text => @item.full_text_html.to_s.html_safe
  end

  def traffic_cop
    return if traffic_cop_warning
    respond_to do |format|
      format.js {
        render  :nothing => true
      }
    end
  end

  protected

    def verify_permission
      verify_ticket_permission(@parent)
    end

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
    
    def build_conversation
      logger.debug "testing the caller class:: #{nscname} and cname::#{cname}"
      @item = self.instance_variable_set('@' + cname, scoper.build(params[nscname]))
      # TODO-RAILS3 need think another better way
      @item.notable = @parent
      set_item_user
      @item
    end

    def cname
      @cname = "note"
    end

    def nscname
      @nscname = "helpdesk_note"
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
    
    def set_default_source
      @item.source = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"] if params[:helpdesk_note][:source].blank?
    end

    def after_restore_url
      :back
    end

    def process_and_redirect
      Thread.current[:notifications] = current_account.email_notifications
      options = {}
      options.merge!({:human=>true}) if(!params[:human].blank? && params[:human].to_s.eql?("true"))  #to avoid unneccesary queries to users
      url_redirect = params[:redirect_to].present? ? TICKET_REDIRECT_MAPPINGS[params[:redirect_to]] : item_url
      
    respond_to do |format|
        format.html { redirect_to url_redirect }
        format.xml  { render :xml => @item.to_xml(options), :status => :created, :location => url_for(@item) }
        format.json { render :json => @item.to_json(options) }
        format.js { 
          update_activities
          render :file => "helpdesk/notes/create.rjs" 
        }
        format.mobile {
          render :json => {:success => true,:item => @item}.to_json
        }
        format.nmobile {
            render :json => {:server_response => true}.to_json
        }
      end
      
      ensure
        Thread.current[:notifications] = nil
    end

    def create_error(note_type = nil)
      respond_to do |format|
        format.js { render :file => "helpdesk/notes/error.rjs", :locals => { :note_type => note_type} }
        format.html { redirect_to @parent }
        format.nmobile { render :json => { :server_response => false } }
        format.any(:json, :xml) { render request.format.to_sym => @item.errors, :status => 400 }
      end
    end
    
    private
      
      def add_forum_post
        @topic = Topic.find_by_id_and_account_id(@parent.ticket_topic.topic_id,current_account.id)
        if !@topic.locked?
          @post  = @topic.posts.build(:body_html => params[:helpdesk_note][:note_body_attributes][:body_html])
          @post.user = current_user
          @post.account_id = current_account.id
          attachment_builder(@post, params[:helpdesk_note][:attachments], params[:cloud_file_attachments] )
          @post.save!
        end
      end
      
      def set_quoted_text
        @item.quoted_text = params[:quoted_text].present? && params[:quoted_text] == 'true'
      end
      
      def set_ticket_status
        if privilege?(:edit_ticket_properties) && !params[:ticket_status].blank?
          @item.notable.status = params[:ticket_status]
          Thread.current[:notifications] = current_account.email_notifications
          Thread.current[:notifications][EmailNotification::TICKET_RESOLVED][:requester_notification] = false
        end
      end
      
      def update_activities
        if params[:showing] == 'activities'
          activity_records = @parent.activities.activity_since(params[:since_id])
          @activities = stacked_activities(activity_records.reverse)
        end
      end

      def clear_saved_draft
        remove_tickets_redis_key(HELPDESK_REPLY_DRAFTS % { 
                                    :account_id => current_account.id, 
                                    :user_id => current_user.id, 
                                    :ticket_id => @item.notable_id
                                })
      end

      def flash_message(status)
        if @item.source == Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['mobihelp_app_review']
          flash[:notice] = t(:"flash.tickets.notes.send_review_request.#{status}")
        else
          flash[:notice] = I18n.t(:"flash.general.create.#{status}", :human_name => cname.humanize.downcase)
        end
      end

      def note_to_kbase
        begin
          create_article if @publish_solution
        rescue Exception => e
          NewRelic::Agent.notice_error(e)
        end
      end

      def has_unseen_notes?
        return false if params["last_note_id"].nil?
        last_public_note    = @parent.notes.visible.last_traffic_cop_note.first
        late_public_note_id = last_public_note.blank? ? -1 : last_public_note.id
        return late_public_note_id > params["last_note_id"].to_i
      end

      def traffic_cop_warning
        return unless has_unseen_notes?
        @notes = @parent.conversation_since(params[:since_id]).reverse
        @public_notes = @notes.select{ |note| note.private == false || note.incoming == true }
        respond_to do |format|
          format.js {
            render :file => "helpdesk/notes/traffic_cop.rjs" and return true
          }
          format.nmobile {
            note_arr = []
            @public_notes.each do |note|
              note_arr << note.to_mob_json
            end
            render :json => { :traffic_cop_warning => true, :notes => note_arr }
          }
        end
      end

      def check_for_public_notes
        traffic_cop_warning unless params[:helpdesk_note][:private].to_s.to_bool
      end
end

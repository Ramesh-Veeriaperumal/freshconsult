class Helpdesk::ConversationsController < ApplicationController
  
  helper  Helpdesk::TicketsHelper#TODO-RAILS3
  
  before_filter :load_parent_ticket_or_issue
  
  include HelpdeskControllerMethods
  include ParserUtil
  include Conversations::Email
  include Conversations::Twitter
  include Facebook::Core::Util
  include Helpdesk::Activities
  include Redis::RedisKeys
  include Redis::TicketsRedis
  include Social::Util
  helper Helpdesk::NotesHelper
  
  before_filter :build_note_body_attributes, :build_conversation, :except => [:full_text]
  before_filter :validate_fwd_to_email, :only => [:forward]
  before_filter :check_for_kbase_email, :set_quoted_text, :only => [:reply]
  before_filter :set_default_source, :set_mobile, :prepare_mobile_note,
    :fetch_item_attachments, :set_native_mobile, :except => [:full_text]
  before_filter :set_ticket_status, :except => :forward
  before_filter :load_item, :only => [:full_text]

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
      begin
        create_article if @publish_solution
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
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
    error_message, @tweet_body = validate_tweet(tweet_text, "@#{@parent.requester.twitter_id}")
    if error_message.blank?
      if @item.save_note 
        twt_type = Social::Tweet::TWEET_TYPES.rassoc(params[:tweet_type].to_sym) ? params[:tweet_type] : "mention"
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

  def full_text
    render :text => @item.full_text_html.to_s.html_safe
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
    
    def build_conversation
      logger.debug "testing the caller class:: #{nscname} and cname::#{cname}"
      @item = self.instance_variable_set('@' + cname,
        scoper.is_a?(Class) ? scoper.new(params[nscname]) : scoper.build(params[nscname]))
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
      end
    end
    
    private
      
      def add_forum_post
        @topic = Topic.find_by_id_and_account_id(@parent.ticket_topic.topic_id,current_account.id)
        if !@topic.locked?
          @post  = @topic.posts.build(:body_html => params[:helpdesk_note][:note_body_attributes][:body_html])
          @post.user = current_user
          @post.account_id = current_account.id
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
end

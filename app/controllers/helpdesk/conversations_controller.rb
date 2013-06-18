class Helpdesk::ConversationsController < ApplicationController
  
  helper 'helpdesk/tickets'
  
  before_filter :load_parent_ticket_or_issue
  
  include HelpdeskControllerMethods
  include ParserUtil
  include Conversations::Email
  include Conversations::Twitter
  include Conversations::Facebook
  include Helpdesk::Activities
  
  before_filter :build_note_body_attributes, :build_conversation
  before_filter :validate_fwd_to_email, :only => [:forward]
  before_filter :check_for_kbase_email, :set_quoted_text, :only => [:reply]
  before_filter :set_default_source, :set_mobile, :prepare_mobile_note,
    :fetch_item_attachments
  before_filter :set_ticket_status, :except => :forward
    
  def reply
    build_attachments @item, :helpdesk_note
    @item.send_survey = params[:send_survey]
    if @item.save
      add_forum_post if params[:post_forums]
      begin
        create_article if @publish_solution
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
      process_and_redirect
    else
      create_error
    end
  end
  
  def forward
    build_attachments @item, :helpdesk_note
    if @item.save
      add_forum_post if params[:post_forums]
      @item.create_fwd_note_activity(params[:helpdesk_note][:to_emails])
      process_and_redirect
    else
      create_error
    end
  end

  def note
    if @item.save
      unless params[:helpdesk_note][:to_emails].blank?
        notify_array = validate_emails(params[:helpdesk_note][:to_emails])
        Helpdesk::TicketNotifier.send_later(:deliver_notify_comment, @parent, @item, 
          @parent.friendly_reply_email,{:notify_emails =>notify_array}) unless notify_array.blank? 
      end
      flash[:notice] = I18n.t(:'flash.general.create.success', :human_name => cname.humanize.downcase)
      process_and_redirect
    else
      create_error
    end
  end

  def twitter
    if @item.save
      twt_type = params[:tweet_type] || :mention.to_s
      if send("send_tweet_as_#{twt_type}")
        flash[:notice] = t(:'flash.tickets.reply.success') 
      else
        flash.now[:notice] = t('twitter.not_authorized')
      end
      process_and_redirect
    else
      create_error
    end
  end

  def facebook
    if @item.save
      send_facebook_reply
      process_and_redirect
    else
      create_error
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
    
    def build_conversation
      logger.debug "testing the caller class:: #{nscname} and cname::#{cname}"
      @item = self.instance_variable_set('@' + cname,
        scoper.is_a?(Class) ? scoper.new(params[nscname]) : scoper.build(params[nscname]))
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
    
      respond_to do |format|
        format.html { redirect_to params[:redirect_to].present? ? params[:redirect_to] : item_url }
        format.xml  { render :xml => @item.to_xml(options), :status => :created, :location => url_for(@item) }
        format.json { render :json => @item.to_json(options) }
        format.js { 
          update_activities
          render :file => "helpdesk/notes/create.rjs" 
        }
        format.mobile {
          render :json => {:success => true,:item => @item}.to_json
        }
      end
      
      ensure
        Thread.current[:notifications] = nil
    end

    def create_error
      redirect_to @parent
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
end

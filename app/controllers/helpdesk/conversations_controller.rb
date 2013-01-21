class Helpdesk::ConversationsController < ApplicationController
  
  before_filter :load_parent_ticket_or_issue
  before_filter :build_conversation

  include HelpdeskControllerMethods
  include ParserUtil
  include Conversations::Email
  include Conversations::Twitter
  include Conversations::Facebook
  
  before_filter :validate_attachment_size, :only => [:reply, :forward]
  before_filter :validate_fwd_to_email, :only => [:forward]
  before_filter :check_for_kbase_email, :only => [:reply]
  before_filter :set_default_source, :set_mobile, :prepare_mobile_note
    
  uses_tiny_mce :options => Helpdesk::TICKET_EDITOR

  def reply
    build_attachments @item, :helpdesk_note
    if @item.save
      add_forum_post if params[:post_forums]
      begin
        create_article if @publish_solution
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
      send_email
      post_persist
    else
      create_error
    end
  end

  def forward
    build_attachments @item, :helpdesk_note
    if @item.save
      add_forum_post if params[:post_forums]
      send_email
      @item.create_fwd_note_activity(params[:helpdesk_note][:to_emails])
      post_persist
    else
      create_error
    end
  end

  def add_forum_post
    @topic = Topic.find_by_id_and_account_id(@parent.ticket_topic.topic_id,current_account.id)
    if !@topic.locked?
      @post  = @topic.posts.build(:body_html => params[:helpdesk_note][:body])
      @post.user = current_user
      @post.account_id = current_account.id
      @post.save!
    end
  end

  def note
    if @item.save
      unless params[:helpdesk_note][:to_emails].blank?
        notify_array = validate_emails(params[:helpdesk_note][:to_emails])
        Helpdesk::TicketNotifier.send_later(:deliver_notify_comment, @parent, @item, 
          @parent.friendly_reply_email,{:notify_emails =>notify_array}) unless notify_array.blank? 
      end
      post_persist
    else
      create_error
    end
  end

  def twitter
    if @item.save
      twt_type = params[:tweet_type] || :mention.to_s
      twt = send("send_tweet_as_#{twt_type}")
      @item.create_tweet({:tweet_id => twt.id, :account_id => current_account.id})
      post_persist
    else
      create_error
    end
  end

  def facebook
    if @item.save
      send_facebook_reply  
      post_persist
    else
      create_error
    end
  end
  
  protected

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

    def process_item
      Thread.current[:notifications] = current_account.email_notifications
        @parent.responder ||= current_user 
        unless params[:ticket_status].blank?
          Thread.current[:notifications][EmailNotification::TICKET_RESOLVED][:requester_notification] = false
          @parent.status = Helpdesk::TicketStatus.status_keys_by_name(current_account)[I18n.t(params[:ticket_status])]
        end
      @parent.save
      Thread.current[:notifications] = nil
    end

    def create_error
      redirect_to @parent
    end
end

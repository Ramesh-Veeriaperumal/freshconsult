# Copyright 2014 © Freshdesk Inc. All Rights Reserved.

class Community::Moderation::QueuedPost
  
  include ModerationUtil
  include SpamAttachmentMethods
  include CloudFilesHelper
  include Forum::CheckSpamContent

  attr_accessor :params, :topic, :post, :spam

  def initialize(params)
    @params = params
    get_account
    find_or_initialize_topic
    initialize_post if topic
  end

  def analyze
    return unless topic
    check_for_spam
    moderate
  end

  private
  
    def get_account
      Account.find_by_id(params['account_id']).make_current
    end

    def find_or_initialize_topic
      if params['topic']['id'].blank?
        initialize_topic
      else
        begin
          @topic = Account.current.topics.find(params['topic']['id'])
        rescue Exception => e
          NewRelic::Agent.notice_error(e)
          Rails.logger.error("Error while finding topic in forum_moderation scan! *** #{e}")
        end
      end
    end

    def initialize_topic
      @topic = Account.current.forums.find(params['topic']['forum_id']).topics.new(topic_params)
    end

    def initialize_post
      @post = topic.posts.build(post_params)
      post.published = true
    end

    def topic_params
      {
        :title => params['topic']['title']
      }.merge(common_attributes)
    end

    def post_params
      {
        :body_html => Helpdesk::HTMLSanitizer.clean(params['body_html']),
        :topic => topic,
        :portal => params['portal'],
        :inline_attachment_ids => params['inline_attachment_ids'] || []
      }.merge(common_attributes)
    end

    def common_attributes
    {
      :user_id => params['user']['id'],
      :created_at => Time.at(params['timestamp']).utc,
      :updated_at => Time.at(params['timestamp']).utc
    }
    end

    def check_for_spam
      begin
        post_content = ""
        post_content = Helpdesk::HTMLSanitizer.plain(post.body_html) if post.body_html.present?
        @spam = check_post_content_for_spam(post_content)
        @spam = is_spam?(post, params['request_params']) unless spam
      rescue => e
        Rails.logger.error("Error during check_for_spam :#{e.message} - #{e.backtrace} ")
      end
    end

    def moderate
      if spam
        Rails.logger.info("Spam content detected during moderation, Account Id: #{Account.current.id}, params: #{@params}")
        create_unpublished_post(ForumSpam)
      elsif to_be_moderated?(post)
        create_unpublished_post(ForumUnpublished)
      else
        create_published_post
      end
    end

    def create_unpublished_post(klass)
      spam_params = unpublished_params.merge!(
                    { 'marked_by_filter' => klass.eql?(ForumSpam) ? 1 : 0 }
                    )
      post = klass.build(spam_params)
      notify_error unless post.save
    end

    def create_published_post
      begin
        save_attachments
        post.topic.new_record? ? topic.approve! : post.approve!
      rescue ActiveRecord::RecordInvalid => e
        NewRelic::Agent.notice_error(e)
        Rails.logger.error("Error while saving topic!")
      end
    end 

    def save_attachments
      move_attachments(params['attachments'], post)
      build_cloud_files_attachments(post, params['cloud_file_attachments'])
    end

    def unpublished_params
      {
        'account_id' => Account.current.id,
        'user_timestamp' => timestamp('user'),
        'timestamp' => params['timestamp'],
        'body_html' => Helpdesk::HTMLSanitizer.sanitize_post(params['body_html']),
        'attachments' => params['attachments'].to_json,
        'cloud_file_attachments' => params['cloud_file_attachments'].to_json,
        'inline_attachment_ids' => params['inline_attachment_ids'].to_json,
        'portal' => params['portal']
      }.merge(unpublished_topic_params || {})
    end

    def unpublished_topic_params
      params['topic']['id'].blank? ?  params['topic'] : 
        { 'topic_timestamp' => timestamp('topic')}
    end

    def timestamp(attr)
      params[attr]['id'] * (10 ** 17) + params['timestamp'] * (10 ** 7)
    end

    def notify_error
      error_message = "Forum dynamodb Error : Dynamodb save failed: #{unpublished_params}"
      NewRelic::Agent.notice_error(StandardError.new(error_message))
      Rails.logger.error(error_message)
    end

end
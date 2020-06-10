class TopicObserver < ActiveRecord::Observer

  include CloudFilesHelper

	def before_create(topic)
		set_default_replied_at_and_sticky(topic)
    #setting replied_by needed for API else api has to do item reloads while rendering the response
    topic.replied_by = topic.user_id 
    topic.posts_count = 1 #Default count
    topic.published = true
    topic
	end

  def before_update(topic)
    check_for_changing_forums(topic)
  end

	def before_save(topic)
		topic.topic_changes
	end

	def before_destroy(topic)
    update_post_user_counts(topic)
	end

  def after_save(topic)
    update_forum_counter_cache(topic)
    topic.publishing = true if topic.published_changed? and topic.published?
  end

  def after_commit(topic)
    after_publishing(topic) if topic.publishing
    enqueue_topic_for_spam_check(topic) if topic.safe_send(:transaction_include_action?, :create) || topic.safe_send(:transaction_include_action?, :update)
  end

  def after_update(topic)
    topic.account.clear_forum_categories_from_cache if topic.published_changed? || topic.forum_id_changed?
    return if !topic.stamp_type_changed? or topic.stamp_type.blank?
    send_later(:send_stamp_change_notification, topic, topic.type_name, topic.stamp, User.current.id)
    create_activity(topic, "topic_stamp_#{topic.stamp_type}", User.current)
  end

  def after_create(topic)
    topic.account.clear_forum_categories_from_cache
  end

  def after_publishing(topic)
    monitor_topic(topic)
    create_ticket(topic) if topic.forum.convert_to_ticket? and !topic.user.agent? and !topic.ticket
    create_activity(topic, 'new_topic')
  end

  def monitor_topic topic
    topic.forum.monitorships.active_monitors.includes(:portal).all.each do |monitor|
      next if monitor.user.email.blank? or (topic.user_id == monitor.user_id)
      TopicMailer.send_later(:monitor_email, monitor.user.email, topic, topic.user, monitor.portal, *monitor.sender_and_host, {locale_object: monitor.user})
    end
  end

  def create_ticket topic
    ticket_params = {
      :subject => topic.title, 
      :requester => topic.user,
      :ticket_body_attributes => {
        :description => topic.posts.first.body,
        :description_html => topic.posts.first.body_html
      },
      :source => Account.current.helpdesk_sources.ticket_source_keys_by_token[:forum]
    }
    ticket = topic.account.tickets.build(ticket_params)
    ticket.build_ticket_topic(:topic_id => topic.id)
    copy_attachment(topic, ticket)
    ticket.save_ticket
  end

  def copy_attachment(topic, ticket)
    topic.first_post.attachments.each do |attachment|      
      ticket.attachments.build(content: attachment.to_io, description: attachment.description, account_id: ticket.account_id)
    end
    
    topic.first_post.cloud_files.each do |cloud_file|
      ticket.cloud_files.build({:url => cloud_file.url, :application_id => cloud_file.application_id, :filename => cloud_file.filename })
    end
  end

  def send_stamp_change_notification(topic, forum_type, current_stamp, current_user_id)
    topic.monitorships.active_monitors.all(:include => [:portal, :user]).each do |monitor|
      next if monitor.user.email.blank? or (current_user_id == monitor.user_id)
      TopicMailer.send_email(:stamp_change_email, monitor.user, monitor.user.email, topic, topic.user, current_stamp, forum_type, monitor.portal, *monitor.sender_and_host)
    end
  end
  
  def before_destroy(topic)
    create_activity(topic, 'delete_topic', User.current) unless topic.trash
  end

	def after_destroy(topic)
		topic.account.clear_forum_categories_from_cache
		update_forum_counter_cache(topic)
		Community::ClearModerationRecords.perform_async(topic.id, topic.class.to_s)
	end

private

	def set_default_replied_at_and_sticky(topic)
      topic.replied_at = Time.now.utc
      topic.sticky   ||= 0
  end

  def check_for_changing_forums(topic)
      old = Topic.find(topic.id)
      @old_forum_id = old.forum_id if old.forum_id != topic.forum_id
      true
  end

  def update_forum_counter_cache(topic)
    # Forum Sidebar Cache is cleared from here
    # As forum callbacks will not be fired from here.
    topic.account.clear_forum_categories_from_cache if topic.published_changed? || topic.forum_id_changed?
    forum_conditions = ['topics_count = ?', Topic.where(forum_id: topic.forum_id, published: true).count(:id)]
    # if the topic moved forums
    if !topic.frozen? && @old_forum_id && @old_forum_id != topic.forum_id
      Post.where(['topic_id = ?', topic.id]).update_all(['forum_id = ?', topic.forum_id])
      Forum.where(['id = ?', @old_forum_id]).update_all(['topics_count = ?, posts_count = ?', Topic.where(forum_id: @old_forum_id, published: true).count(:id), Post.where(forum_id: @old_forum_id, published: true).count(:id)])
    end
    # if the topic moved forums or was deleted
    if topic.frozen? || (@old_forum_id && @old_forum_id != topic.forum_id)
      forum_conditions.first << ', posts_count = ?'
      forum_conditions       << Post.where(forum_id: topic.forum_id, published: true).count(:id)
    end
    # User doesn't have update_posts_count method in SB2, as reported by Ryan
    # @voices.each &:update_posts_count if @voices
    Forum.where(['id = ?', topic.forum_id]).update_all(forum_conditions)
    @old_forum_id = @voices = nil
  end

  def update_post_user_counts(topic)
      @voices = topic.voices.to_a
  end

  def create_activity(topic, type, user = topic.user)
    topic.activities.create(
      :description => "activities.forums.#{type}.long",
      :short_descr => "activities.forums.#{type}.short",
      :account       => topic.account,
      :user          => user,
      :activity_data => {
                          :path        => Rails.application.routes.url_helpers.discussions_topic_path(topic.id),
                          'forum_name' => h(topic.forum.to_s),
                          :url_params  => {
                                            :topic_id => topic.id,
                                            :path_generator => 'discussions_topic_path'
                                          },
                          :title        => h(topic.to_s),
                          :version      => 2
                        }
    )
  end

  def enqueue_topic_for_spam_check(topic)
    if !topic.account.launched?(:forum_post_spam_whitelist) && ( (topic.account.created_at >= (Time.zone.now - 90.days)) || (topic.account.subscription.present? && topic.account.subscription.free?))
      Rails.logger.debug "Comes inside enqueue_topic_for_spam_check loop for account : #{topic.account} and Topic #{topic.id}"
      Forum::CheckContentForSpam.perform_async({:topic_id =>topic.id})
    end
  end
end

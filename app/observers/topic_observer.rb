class TopicObserver < ActiveRecord::Observer

	def before_create(topic)
		set_default_replied_at_and_sticky(topic)
    #setting replied_by needed for API else api has to do item reloads while rendering the response
    topic.replied_by = topic.user_id 
    topic.posts_count = 1 #Default count
    topic.published ||= (topic.user.agent? || topic.import_id?) #Agent Topics are approved by default.
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
    after_publishing(topic) if topic.published_changed? and topic.published?
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
    create_activity(topic, 'new_topic')
  end

  def monitor_topic topic
    send_later(:send_monitorship_emails, topic)
  end

  def send_monitorship_emails topic
    topic.forum.monitorships.active_monitors.all(:include => :portal).each do |monitor|
      next if monitor.user.email.blank? or (topic.user_id == monitor.user_id)
      TopicMailer.monitor_email(monitor.user.email, topic, topic.user, monitor.portal, *monitor.sender_and_host)
    end
  end

  def send_stamp_change_notification(topic, forum_type, current_stamp, current_user_id)
    topic.monitorships.active_monitors.all(:include => [:portal, :user]).each do |monitor|
      next if monitor.user.email.blank? or (current_user_id == monitor.user_id)
      TopicMailer.stamp_change_email(monitor.user.email, topic, topic.user, current_stamp, forum_type, monitor.portal, *monitor.sender_and_host)
    end
  end
  
  def before_destroy(topic)
    create_activity(topic, 'delete_topic', User.current) unless topic.trash
  end

	def after_destroy(topic)
		topic.account.clear_forum_categories_from_cache
		update_forum_counter_cache(topic)
		delete_spam_posts(topic)
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
    forum_conditions = ['topics_count = ?', Topic.count(:id, :conditions => {:forum_id => topic.forum_id, :published => true})]
    # if the topic moved forums
    if !topic.frozen? && @old_forum_id && @old_forum_id != topic.forum_id
      Post.update_all ['forum_id = ?', topic.forum_id], ['topic_id = ?', topic.id]
      Forum.update_all ['topics_count = ?, posts_count = ?',
        Topic.count(:id, :conditions => {:forum_id => @old_forum_id, :published => true }),
        Post.count(:id,  :conditions => {:forum_id => @old_forum_id, :published => true })], ['id = ?', @old_forum_id]
    end
    # if the topic moved forums or was deleted
    if topic.frozen? || (@old_forum_id && @old_forum_id != topic.forum_id)
      forum_conditions.first << ", posts_count = ?"
      forum_conditions       << Post.count(:id, :conditions => {:forum_id => topic.forum_id, :published => true})
    end
    # User doesn't have update_posts_count method in SB2, as reported by Ryan
    # @voices.each &:update_posts_count if @voices
    Forum.update_all forum_conditions, ['id = ?', topic.forum_id]
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

  def delete_spam_posts(topic)
    Post::SPAM_SCOPES_DYNAMO.each do |k, klass|
      next if SpamCounter.count(topic.id, k).zero?
      Resque.enqueue(Workers::Community::DeleteTopicSpam, 
                      {
                        :account_id => topic.account.id,
                        :topic_id => topic.id,
                        :klass => klass.to_s  
                      })
    end
  end

end

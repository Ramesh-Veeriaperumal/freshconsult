class TopicObserver < ActiveRecord::Observer

  include ActionController::UrlWriter

	def before_create(topic)
		set_default_replied_at_and_sticky(topic)
    topic.posts_count = 1 #Default count
    topic.published = topic.user.agent? #Agent Topics are approved by default.
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
    create_activity(topic, 'published_topic') if topic.published_changed? and topic.published?
	end

  def after_update(topic)
    return if !topic.stamp_type_changed? or topic.stamp_type.blank?
    create_activity(topic, "topic_stamp_#{topic.stamp_type}", User.current)
  end

  def after_create(topic)
    monitor_topic(topic)
    create_activity(topic, 'new_topic') if topic.published?
  end

  def monitor_topic topic
    send_later(:send_monitorship_emails, topic)
  end

  def send_monitorship_emails topic
    topic.forum.monitorships.active_monitors.each do |monitor|
      monitorship_email = monitor.user.email
      TopicMailer.deliver_monitor_email!(monitorship_email,topic,topic.user) unless monitorship_email.blank? or (topic.user_id == monitor.user_id)
    end
  end

	def after_destroy(topic)
		update_forum_counter_cache(topic)
    create_activity(topic, 'delete_topic', User.current) unless topic.trash
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
                          :path        => category_forum_topic_path(topic.forum.forum_category_id,
                                          topic.forum_id, topic.id),
                          'forum_name' => h(topic.forum.to_s),
                          :url_params  => {
                                            :category_id => topic.forum.forum_category_id,
                                            :forum_id => topic.forum_id,
                                            :topic_id => topic.id,
                                            :path_generator => 'category_forum_topic_path'
                                          },
                          :title        => h(topic.to_s),
                          :version      => 2
                        }
    )
  end

end

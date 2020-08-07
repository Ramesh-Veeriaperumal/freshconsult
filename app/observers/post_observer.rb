class PostObserver < ActiveRecord::Observer

	def before_create(post)
		post.forum_id = post.topic.forum_id
		post.published = true
    post
	end

	def before_save(post)
		set_body_content(post)
	end

	def after_create(post)
		update_cached_fields(post)
		unless post.topic.last_post_id.nil?
			create_activity(post, 'new_post') if post.published?
		end
	end
  
  def before_destroy(post)
    create_activity(post, 'delete_post', User.current) unless post.trash#TODO-RAILS3
  end

  def after_commit(post)
    enqueue_post_for_spam_check(post) if post.safe_send(:transaction_include_action?, :create)
    Rails.logger.debug "before skip_notification"
    return if post.skip_notification
    Rails.logger.debug  "after skip_notification"
    monitor_reply(post) if post.safe_send(:transaction_include_action?, :create) && post.published?
  end

	def after_destroy(post)
		update_cached_fields(post)
#		create_activity(post, 'delete_post', User.current) unless post.trash#TODO-RAILS3 do it in before destroy
	end

  def monitor_reply(post)
    PostMailer.send_later(:send_monitorship_emails, post)
  end

	def after_update(post)
		update_cached_fields(post) if post.published_changed?
		if post.published_changed?
			if post.original_post?
				post.topic.published = post.published
				post.topic.save
			elsif post.published?
				monitor_reply(post)
			end
		end
		create_activity(post, 'published_post') if post.published_changed? and post.published? and !post.topic.new?
		enqueue_post_for_spam_check(post)
	end

	private

	def set_body_content(post)     
	  post.body = Helpdesk::HTMLSanitizer.plain(post.body_html) unless post.body_html.empty?
    end

    def update_cached_fields(post)
      Forum.where(['id = ?', post.forum_id]).update_all(['posts_count = ?', Post.where(forum_id: post.forum_id, published: true).count(:id)])
      User.update_posts_count(post.user_id)
      post.topic.update_cached_post_fields(post)
  	end

	def create_activity(post, type, user = post.user)
		post.topic.activities.create(
			:description => "activities.forums.#{type}.long",
			:short_descr => "activities.forums.#{type}.short",
			:account 		=> post.account,
			:user 			=> user,
			:activity_data 	=> {
								 :path => Rails.application.routes.url_helpers.discussions_topic_path(post.topic_id),
								 :url_params => {
												 :topic_id => post.topic_id,
												 :path_generator => 'discussions_topic_path'
												},
								 :title => h(post.to_s)
								}
		)
	end

	def enqueue_post_for_spam_check(post)
    if !post.account.launched?(:forum_post_spam_whitelist) && ( (post.account.created_at >= (Time.zone.now - 90.days)) || (post.account.subscription.present? && post.account.subscription.free?))
      Rails.logger.debug "Comes inside enqueue_post_for_spam_check loop for account : #{post.account} and post #{post.id}"
      Forum::CheckContentForSpam.perform_async({:post_id => post.id, :topic_id =>post.topic.id})
    end
  end

end

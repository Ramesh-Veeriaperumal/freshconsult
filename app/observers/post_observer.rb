class PostObserver < ActiveRecord::Observer

	def before_create(post)
		post.forum_id = post.topic.forum_id
		post.published ||= (post.user.agent?  || !post.import_id.nil?) #Agent posts are approved by default.
    post
	end

	def before_save(post)
		set_body_content(post)
	end

	def after_create(post)
		update_cached_fields(post)
		monitor_reply(post) if post.published?
		unless post.topic.last_post_id.nil?
			create_activity(post, 'new_post') if post.published?
		end

	end
  
  def before_destroy(post)
    create_activity(post, 'delete_post', User.current) unless post.trash#TODO-RAILS3
  end

	def after_destroy(post)
		update_cached_fields(post)
#		create_activity(post, 'delete_post', User.current) unless post.trash#TODO-RAILS3 do it in before destroy
	end

	def monitor_reply(post)
    send_later(:send_monitorship_emails, post)
  end

  def send_monitorship_emails(post)
    post.topic.monitorships.active_monitors.all(:include => [:portal, :user]).each do |monitorship|
    	next if monitorship.user.email.blank? or (post.user_id == monitorship.user_id)
    	PostMailer.monitor_email(monitorship.user.email, post, post.user, monitorship.portal, *monitorship.sender_and_host)
    end
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
	end

	private

	def set_body_content(post)     
	  post.body = Helpdesk::HTMLSanitizer.plain(post.body_html) unless post.body_html.empty?
    end

    def update_cached_fields(post)
      Forum.update_all ['posts_count = ?', Post.count(:id, :conditions => {:forum_id => post.forum_id, :published => true })], ['id = ?', post.forum_id]
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

end

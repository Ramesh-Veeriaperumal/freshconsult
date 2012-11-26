class PostObserver < ActiveRecord::Observer

	include Gamification::GamificationUtil
	include ActionController::UrlWriter

	def before_create(post)
		post.forum_id = post.topic.forum_id 
	end

	def before_save(post)
		set_body_content(post)
	end

	def after_create(post)
		update_cached_fields(post)
		monitor_reply(post)
		unless post.topic.last_post_id.nil?
			create_activity(post, 'new_post')
		end
	end

	def after_commit_on_create(post)
		if gamification_feature?(post.account)
			return if (post.user.customer? or post.user_id == post.topic.user_id)
			Resque.enqueue(Gamification::Quests::ProcessPostQuests, { :id => post.id, 
							:account_id => post.account_id }) 
		end
	end

	def after_destroy(post)
		update_cached_fields(post)
		create_activity(post, 'delete_post')
	end

	def monitor_reply(post)
    send_later(:send_monitorship_emails, post)
  end

  def send_monitorship_emails(post)
    post.topic.monitorships.active_monitors.each do |monitorship|
      monitorship_email = monitorship.user.email
      PostMailer.deliver_monitor_email!(monitorship_email,post,post.user) unless monitorship_email.blank?
    end
  end

	private

		def set_body_content(post)     
      post.body = (post.body_html.gsub(/<\/?[^>]*>/, "")).gsub(/&nbsp;/i,"") unless post.body_html.empty?
    end

    def update_cached_fields(post)
      Forum.update_all ['posts_count = ?', Post.count(:id, :conditions => {:forum_id => post.forum_id})], ['id = ?', post.forum_id]
      User.update_posts_count(post.user_id)
      post.topic.update_cached_post_fields(post)
  	end

	def create_activity(post, type)
		post.activities.create(
			:description => "activities.forums.#{type}.long",
			:short_descr => "activities.forums.#{type}.short",
			:account 		=> post.account,
			:user 			=> post.user,
			:activity_data 	=> { 
								 :path => category_forum_topic_path(post.forum.forum_category_id, 
										 post.forum_id, post.topic_id),
								 :url_params => {
												 :category_id => post.forum.forum_category_id, 
												 :forum_id => post.forum_id, 
												 :topic_id => post.topic_id,
												 :path_generator => 'category_forum_topic_path'
												},
								 :title => post.to_s
								} 
		)
	end

end
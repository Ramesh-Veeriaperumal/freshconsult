module SpamPostMethods
	include Redis::RedisKeys
	include Redis::OthersRedis

	def create_dynamo_post(post, params = {})
		# We show only last one month data in the moderation queue. 
		# The below condition will skip creating entry in dynamo if its an older post.
		return true if post.created_at.utc < (Time.now - ForumSpam::UPTO).utc
		klass = post.spam? || params[:spam] ? ForumSpam : ForumUnpublished
		@spam = klass.build(spam_params(post))
		backup_and_save(post)
	end

	def backup_and_save(post)
		@spam.attachments = {
			:file_names => backup_attachments(post),
			:folder => cdn_folder_name
			} if post.attachments
		@spam.cloud_file_attachments = (post.cloud_files.map do |cloud_file|
			{:link => cloud_file.url, :name => cloud_file.filename, :provider => cloud_file.application.name}.to_json
		end).to_json if post.cloud_files
		@spam.save ? report_post(@spam, Post::REPORT[:spam]) : false
	end

	def spam_params(post)
		{
			:account_id => Account.current.id,
			:user_timestamp => timestamp(post, 'user_id'),
			:timestamp => post.created_at.to_f,
			:body_html => post.body_html,
			:marked_by_filter => false,
			:portal => portal_id(post)
		}.merge(spam_topic_params(post) || {}).delete_if { |k, v| v.blank? }
	end

	def spam_topic_params(post)
		if post.original_post?
			{
				:title => post.topic.title,
				:forum_id => post.topic.forum_id
			}
		else
			{
				:topic_timestamp => timestamp(post, 'topic_id')
			}
		end
	end

	def timestamp(post, att)
		post.safe_send(att) * (10 ** 17) + post.created_at.to_f * (10 ** 7)
	end

	def report_post(post, type)
		params = { :id => post.class.eql?(Post) ? post.id : post.timestamp,
				   :account_id => post.account_id,
				   :report_type => type,
				   :klass_name => post.class.name
				}
		if redis_key_exists?(REPORT_POST_SIDEKIQ_ENABLED)
	        Community::ReportPostWorker.perform_async(params)
	    else
	        Resque.enqueue(Workers::Community::ReportPost, params)
        end
	end

	def portal_id(post) 
		user_monitor = post.topic.monitorships.by_user(post.topic.user).first
		user_monitor.nil? ? Account.current.main_portal.id : user_monitor.portal_id
	end
end

module Workers::Community::MergeTopics
	extend Resque::AroundPerform
	@queue = 'merge_topics'
	STATES_TO_BE_MOVED = ["followers", "user_votes"]

	class << self
		
		def perform(args)
			args.symbolize_keys!
			user = find_user(args)
			sources = current_account.topics.find(:all, :conditions => { :id => args[:source_topic_ids] })
			target = current_account.topics.find(args[:target_topic_id])
			sources.each do |source|
				aggregate_meta(target, source)
				notify(source, target, user)
				reply_to_source(source, user, args[:source_note]) unless blank_reply?(args[:source_note])
				update_merge_activity(source, target, user)
			end
		end
		
		def current_account
			Account.current
		end

		def find_user(args)
			current_account.users.find(args[:current_user_id]).make_current
		end

		def aggregate_meta(target, source)
		  STATES_TO_BE_MOVED.each do |state|
		    source.send("merge_#{state}", target)
		  end
		end

		def notify(source, target, user)
			source.monitorships.active_monitors.all(:include => :portal).each do |monitor|
				next if monitor.user.email.blank? or (user.id == monitor.user_id)
				TopicMailer.deliver_topic_merge_email(monitor, target, source, *monitor.sender_and_host)
			end
		end

		def reply_to_source(source, user, post)
			post = source.posts.build(
				:body_html => post,
				:forum_id => source.forum_id,
				:user_id => user.id)
			post.account_id = current_account.id
			post.save!
		end

		def update_merge_activity(source, target, user)
	    source.activities.create(
	    	:user_id => user.id,
				:description => 'activities.forums.topic_merge.long',
				:short_descr => 'activities.forums.topic_merge.short',
				:activity_data => {
					:path => "/discussions/topics/#{source.id}",
					:url_params => {
						:topic_id => source.id,
					  :path_generator => 'discussions_topic_path'
					},
					:title => h(source.title),
					'eval_args' => { 'target_topic_path' => ['target_topic_path', target.id] }
				}
			)
		end

		def blank_reply?(note)
			return true if note.blank?
			['&nbsp;', '<br>', '<br />', '<p>', '</p>'].each { |str| note.gsub!(str, '') }
			note.blank?
		end

	end

end
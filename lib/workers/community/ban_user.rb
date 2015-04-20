class Workers::Community::BanUser
  extend Resque::AroundPerform

  @queue = 'ban_user'

  class << self

  	include SpamAttachmentMethods
  	include SpamPostMethods

	  def perform(params)

	  	spam_user = Account.current.all_users.find(params[:spam_user_id])

	  	# posts in Dynamo
	  	ban_posts_dynamo(params[:account_id], spam_user)

			# published posts
			ban_published_posts(spam_user)

		end

		def ban_posts_dynamo(account_id, spam_user)
			results = ForumUnpublished.by_user(spam_user.id, next_user_timestamp(spam_user))
			while(results.present?)
				convert_to_spam(results)
				last = results.last.user_timestamp
				results = ForumUnpublished.by_user(spam_user.id, last)
			end	
		end

		def ban_published_posts(spam_user)
			spam_user.posts.each do |post|
				ban_post(post) if post.present? and post.topic.present?
			end
		end

		def convert_to_spam(posts)
			posts.each do |p|
				p.destroy if build_spam_post(p.attributes)
				report_post(@post, Post::REPORT[:spam])
			end
		end

		def build_spam_post(params)
			@post = ForumSpam.build(params)
			@post.save
		end

		def next_user_timestamp(spam_user)
			spam_user.id * 10.power!(17) + (Time.now - ForumSpam::UPTO).utc.to_f * 10.power!(7)
		end

		def ban_post(post)
			if create_dynamo_post(post, {:spam => true})
  			post.original_post? ? post.topic.destroy : post.destroy 
  		end
		end

	end
end

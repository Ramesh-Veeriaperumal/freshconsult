# Copyright 2014 © Freshdesk Inc. All Rights Reserved.
module Community::Moderation::MoveToDynamo

	include Redis::RedisKeys
  include Redis::OthersRedis

	def ban
		@spam_post.user.update_attribute(:deleted, true)

    if redis_key_exists?(SIDEKIQ_BAN_USER)
      Community::ForumBanUser.perform_async({ :spam_user_id => @spam_post.user.id })
    else
  		Resque.enqueue(Workers::Community::BanUser,
  							{
  								:account_id => current_account.id,
  								:user_id => current_user.id,
  								:spam_user_id => @spam_post.user.id
  							})
    end


		respond_back
	end

	def mark_as_spam

		spam_saved = create_dynamo_post(@post, {:spam => true})

		topic_deleted = @post.topic.destroy if @post.original_post?

		@post.destroy if !topic_deleted && spam_saved

		respond_back(discussions_unpublished_filter_path(:filter => :spam))

	end

	def spam_multiple
		if params[:ids].present?
			mark_spam(params[:ids])
			move_posts(params[:ids])
			flash[:notice] = I18n.t('topic.bulk_spam')
		end
		respond_back
	end


	private

		def mark_spam(ids)
			current_account.topics.find(ids).each do |item|
				item.posts.first.mark_as_spam!
			end
		end

		def move_posts(ids)
			if redis_key_exists?(FORUM_POSTS_SPAM_MARKER)
				Community::ForumPostSpamMarker.perform_async({ topic_ids: ids })
			else
				Resque.enqueue(Workers::Community::BulkSpam, 
								{
									:account_id => current_account.id,
									:topic_ids => ids
								}
				)
			end
		end

end
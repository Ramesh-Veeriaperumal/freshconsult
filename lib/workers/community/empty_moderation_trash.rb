class Workers::Community::EmptyModerationTrash
  extend Resque::AroundPerform

  @queue = 'empty_moderation_trash'

  class << self

	  def perform(params)
			ForumSpam.delete_account_spam
		end

		def empty_db_spam
			Account.current.posts.find_in_batches(:conditions => ["trash = ?",true]) do |posts|
				posts.each do |post|
					delete_post(post) if presence(post)
				end
			end
		end

		def delete_post(post)
			if post.original_post?
				post.topic.trash = true	
				post.topic.destroy
			else
				post.destroy
			end
		end

		def presence(post)
			post.present? and post.topic.present?
		end

	end
end

class Workers::Community::EmptyModerationTrash
  extend Resque::AroundPerform

  @queue = 'empty_moderation_trash'

  class << self

	  def perform(params)

	  	Account.current.posts.trashed.find_in_batches do |batch|
				batch.each do |post|
					if post.topic.posts_count > 0
						post.destroy
					else
						post.topic.trash = true
						post.topic.destroy
					end
				end
			end

	  end

	  def load_user(id)
	  	user = Account.current.users.find(id)
	  	user.make_current
	  end
	end
end

class Workers::Community::EmptyModerationTrash
  extend Resque::AroundPerform

  @queue = 'empty_moderation_trash'

  class << self

	  def perform(params)

			Account.current.posts.find_in_batches(:conditions => ["trash = ?",true]) do |batch|
				batch.each do |post|
					if post.present? and post.topic.present?
						if post.original_post?
							post.topic.trash = true	
							post.topic.destroy
						else
							post.destroy
						end
					end
				end
			end
		end
	end
end

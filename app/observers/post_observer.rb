require "post"

class PostObserver < ActiveRecord::Observer

	include ProcessQuests

	def after_create(post)
		process_forums_quest(post)
	end

end
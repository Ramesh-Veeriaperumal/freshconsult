class PostObserver < ActiveRecord::Observer

	include Gamification::Quests::ProcessPostQuests

	def after_create(post)
		evaluate_post_quests(post)
	end

end
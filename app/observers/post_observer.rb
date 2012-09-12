class PostObserver < ActiveRecord::Observer

	include Gamification::Quests::ProcessPostQuests
	include Gamification::GamificationUtil

	def after_create(post)
		evaluate_post_quests(post) if gamification_feature?(post.account)
	end

end
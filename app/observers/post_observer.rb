class PostObserver < ActiveRecord::Observer

	include Gamification::GamificationUtil

	def after_create(post)
		if gamification_feature?(post.account)
			return if (post.user.customer? or post.user_id == post.topic.user_id)
			Resque.enqueue(Gamification::Quests::ProcessPostQuests, { :id => post.id, 
							:account_id => post.account_id }) 
		end
	end

end
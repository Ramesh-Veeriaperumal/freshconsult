class TopicObserver < ActiveRecord::Observer

	include Gamification::GamificationUtil

	TOPIC_UPDATE_ATTRIBUTES = ["forum_id", "user_votes"]

	def after_create(topic)
		add_resque_job(topic) if gamification_feature?(topic.account)
	end

	def after_update(topic)
		changed_topic_attributes = topic.changed & TOPIC_UPDATE_ATTRIBUTES
		add_resque_job(topic) if gamification_feature?(topic.account) && changed_topic_attributes.any?
	end

	def add_resque_job(topic)
		return if topic.user.customer?
		Resque.enqueue(Gamification::Quests::ProcessTopicQuests, { :id => topic.id, 
						:account_id => topic.account_id })
	end

end


class TopicObserver < ActiveRecord::Observer

	include Gamification::Quests::ProcessTopicQuests

	TOPIC_UPDATE_ATTRIBUTES = ["forum_id", "user_votes"]

	def after_create(topic)
		evaluate_topic_quests(topic)
	end

	def after_update(topic)
		changed_topic_attributes = topic.changed & TOPIC_UPDATE_ATTRIBUTES
		evaluate_topic_quests(topic) if changed_topic_attributes.any?
	end


end


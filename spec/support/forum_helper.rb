require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module ForumHelper

	def create_test_category
		forum_category = Factory.build(:forum_category, :account_id => @account.id)
		forum_category.save(false)
		forum_category
	end

	def create_test_forum(forum_category,type = 1)
		forum = Factory.build(
							:forum, 
							:account_id => @account.id, 
							:forum_category_id => forum_category.id,
							:forum_type => type
							)
		forum.save(false)
		forum
	end

	def create_test_topic(forum)
		topic = Factory.build(
							:topic, 
							:account_id => @account.id, 
							:forum_id => forum.id,
							:user_id => @customer.id
							)
		topic.save(true)
		topic
	end

	def create_test_post(topic)
		post = Factory.build(
							:post, 
							:account_id => @account.id, 
							:topic_id => topic.id,
							:user_id => @customer.id
							)
		post.save(true)
		post			
	end

	def create_ticket_topic_mapping(topic,ticket)
		ticket_topic = Factory.build(
											:ticket_topic,
											:account_id => @account.id,
											:topic_id => topic.id,
											:ticket_id => ticket.id 
										)
		ticket_topic.save(true)
		ticket_topic
	end

	def publish_topic(topic)
		topic.published = true
		topic.save(true)
		topic
	end

	def mark_as_spam(post)
		post.mark_as_spam!
		post
	end

	def publish_post(post)
		post.approve!
		post
	end
end
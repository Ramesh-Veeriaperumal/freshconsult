require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module ForumHelper

	def create_test_category
		forum_category = Factory.build(:forum_category, :account_id => @account.id)
		forum_category.save(false)
		forum_category
	end

	def create_test_forum(forum_category,type)
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
end
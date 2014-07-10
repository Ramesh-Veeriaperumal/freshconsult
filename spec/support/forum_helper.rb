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

	def create_test_topic(forum, user = @customer )
		forum_type_symbol = Forum::TYPE_KEYS_BY_TOKEN[Forum::TYPE_SYMBOL_BY_KEY[forum.forum_type]]
		stamp_type = Topic::ALL_TOKENS_FOR_FILTER[forum_type_symbol].keys.sample
		topic = Factory.build(
							:topic, 
							:account_id => @account.id, 
							:forum_id => forum.id,
							:user_id => user.id,
							:stamp_type => stamp_type
							)
		topic.save(true)
		post = Factory.build(
							:post,
							:account_id => @account.id,
							:topic_id => topic.id,
							:user_id => user.id,
							)
		post.save!
		publish_post(post)
		topic.reload
	end

	def create_test_post(topic, user = @customer)
		post = Factory.build(
							:post, 
							:account_id => @account.id, 
							:topic_id => topic.id,
							:user_id => user.id
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

	def monitor_topic(topic)
		monitorship = Factory.build(
									:monitorship,
									:monitorable_id => topic.id,
									:user_id => @user.id,
									:active => 1,
									:account_id => @account.id,
									:monitorable_type => "Topic" 
									)
		monitorship.save(true)
	end

	def lock_topic(topic)
		topic.locked = true
		topic.save
		topic
	end

	def mark_as_answer(post)
		post.toggle_answer
		post
	end

	def change_visibility(forum, visibility)
		forum.update_attributes(:forum_visibility => visibility)
		forum
	end
	
	def destroy_session
		@current_user_session = UserSession.find
		@current_user_session.destroy
	end
end
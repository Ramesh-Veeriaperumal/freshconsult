module ForumHelper

	PHONE_NUMBERS = ["1-234-567-8901", "1-234-567-8901 x1234", "1-234-567-8901 ext1234", "1 (234) 567-8901", "12345678901",
					 "+4112345678", "+44123456789", "9941751339", "+91-9941751339", "+91 9941751339", "1 (234) 567-8901",
					 "12345678901x1234", "044 2656 7136", "(0055)(123)8575973", "1-234-567-8901 x1234", "+1 800 555-1234"]

	def create_test_category
    forum_category = FactoryGirl.build(:forum_category, :account_id => RSpec.configuration.account.id,
                                                    :name => Faker::Lorem.sentence(2))
		forum_category.save(validate: false)
		forum_category
	end

	def create_test_forum(forum_category,type = 1)
		forum = FactoryGirl.build(
							:forum, 
							:account_id => RSpec.configuration.account.id, 
							:forum_category_id => forum_category.id,
							:forum_type => type
							)
		forum.save(validate: false)
		forum
	end

	def create_test_topic(forum, user = @customer )
		forum_type_symbol = Forum::TYPE_KEYS_BY_TOKEN[Forum::TYPE_SYMBOL_BY_KEY[forum.forum_type]]
		stamp_type = Topic::ALL_TOKENS_FOR_FILTER[forum_type_symbol].keys.sample
		topic = FactoryGirl.build(
							:topic, 
							:account_id => RSpec.configuration.account.id, 
							:forum_id => forum.id,
							:user_id => user.id,
							:stamp_type => stamp_type
							)
		topic.save(true)
		post = FactoryGirl.build(
							:post,
							:account_id => RSpec.configuration.account.id,
							:topic_id => topic.id,
							:user_id => user.id,
							)
		post.save!
		publish_post(post)
		topic.reload
	end

	def create_test_post(topic, user = @customer)
		post = FactoryGirl.build(
							:post, 
							:account_id => RSpec.configuration.account.id, 
							:topic_id => topic.id,
							:user_id => user.id
							)
		post.save(true)
		post			
	end

	def quick_create_post
		create_test_post(create_test_topic(create_test_forum(create_test_category)))
	end

	def create_ticket_topic_mapping(topic,ticket)
		ticket_topic = FactoryGirl.build(
											:ticket_topic,
											:account_id => RSpec.configuration.account.id,
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

	def monitor_topic(topic, user = @user, portal_id = nil)
		monitorship = FactoryGirl.build(
									:monitorship,
									:monitorable_id => topic.id,
									:user_id => user.id,
									:active => 1,
									:account_id => RSpec.configuration.account.id,
									:monitorable_type => "Topic",
									:portal_id => portal_id
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
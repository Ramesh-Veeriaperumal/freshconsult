require 'spec_helper'

describe Support::Discussions::TopicsController do
	integrate_views
  	setup :activate_authlogic
  	self.use_transactional_fixtures = false

	before(:all) do
		@category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
		@user = add_new_user(@account)
	end

	before(:each) do
        @request.env['HTTP_REFERER'] = 'support/discussions'
        log_in(@user)
	end

	after(:all) do
		@category.destroy
	end


	it "should render show page on get 'show'" do
		topic = publish_topic(create_test_topic(@forum))

		get :show, :id => topic.id

		response.should render_template 'support/discussions/topics/show.portal'
	end

	it "should render new page on get 'new'" do
		get :new

		response.should render_template 'support/discussions/topics/new.portal'
	end

	it "should increase hit count on get 'hit'" do
		topic = publish_topic(create_test_topic(@forum))
		hit_count = topic.hits

		get :hit, :id => topic.id
		
		topic.reload
		topic.hits.should be_eql(hit_count + 1)
	end

	it "should render edit page on get 'edit'" do
		topic = publish_topic(create_test_topic(@forum, @user))

		get :edit, :id => topic.id

		topic_from_controller = controller.instance_variable_get(:@topic)
		topic_from_controller.should eql topic
		response.should render_template 'support/discussions/topics/new.portal'
	end


	it "should create a topic on post 'create'" do
		topic_title = Faker::Lorem.sentence(1)
		post_body = Faker::Lorem.paragraph
		old_follower_count = Monitorship.count

		post :create,
			:topic =>
					{:title=> topic_title, 
					:body_html=>"<p>#{post_body}</p>", 
					:forum_id=> @forum.id,
					:sticky => true }

		new_topic = @account.topics.find_by_title(topic_title)
		new_topic.forum_id.should eql @forum.id
		new_topic.user_id.should eql @user.id
		new_topic.account_id.should eql @account.id

		new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
		new_post.topic_id.should eql new_topic.id
		new_post.user_id.should eql @user.id
		new_post.account_id.should eql @account.id

		Monitorship.count.should eql old_follower_count + 1
		Monitorship.last.portal_id.should_not be_nil
		response.should redirect_to 'support/discussions'
	end

	it "should not create a topic on post 'create' when post is invalid" do
		topic_title = Faker::Lorem.sentence(1)

		post :create,
			:topic =>
					{:title=> topic_title, 
					:body_html=> "", 
					:forum_id=> @forum.id }

		@account.topics.find_by_title(topic_title).should be_nil
		@account.posts.find_by_body_html("").should be_nil

		response.should render_template 'support/discussions/topics/new.portal'
	end


	it "should update a topic on put 'update'" do
		topic = publish_topic(create_test_topic(@forum, @user))
		new_topic_title = Faker::Lorem.sentence(1)
		new_post_body = Faker::Lorem.paragraph

		put :update,
			:id => topic.id,
			:topic =>
					{:title=> new_topic_title, 
					:body_html=>"<p>#{new_post_body}</p>"}

		topic.reload
		topic.title.should eql new_topic_title
		topic.forum_id.should eql @forum.id
		topic.user_id.should eql @user.id
		topic.account_id.should eql @account.id

		post = @account.posts.find_by_body_html("<p>#{new_post_body}</p>")
		post.topic_id.should eql topic.id
		post.user_id.should eql @user.id
		post.account_id.should eql @account.id

		response.should redirect_to "support/discussions/topics/#{topic.id}"
	end

	it "should deny access when someone tries to update a topic on put 'update'" do
		topic = publish_topic(create_test_topic(@forum))
		create_test_post(topic)
		new_topic_title = Faker::Lorem.sentence(1)
		new_post_body = Faker::Lorem.paragraph

		put :update,
			:id => topic.id,
			:topic =>
					{:title=> new_topic_title, 
					:body_html=>"<p>#{new_post_body}</p>"}

		topic.reload
		topic.title.should_not eql new_topic_title
		topic.posts.first.body_html.should_not eql "<p>#{new_post_body}</p>"
		response.should redirect_to "/support/login"
	end

	# it "should not update a topic on put 'update' when post is invalid" do
	# 	topic = publish_topic(create_test_topic(@forum, @user))
	# 	create_test_post(topic, @user)
	# 	new_topic_title = Faker::Lorem.sentence(1)

	# 	put :update,
	# 		:id => topic.id,
	# 		:topic =>
	# 				{:title=> new_topic_title, 
	# 				:body_html=> ""}

	# 	@account.topics.find_by_title(new_topic_title).should be_nil
	# 	@account.posts.find_by_body_html("").should be_nil

	# 	response.should redirect_to "support/discussions/topics/new.portal"
	# end

	it "should delete a topic on delete 'destroy'" do
		topic = publish_topic(create_test_topic(@forum, @user))
		post = create_test_post(topic, @user)

		delete :destroy,
			:id => topic.id

		@account.topics.find_by_id(topic.id).should be_nil
		@account.posts.find_by_id(post.id).should be_nil
		response.should redirect_to 'support/discussions'
	end

	it "should toggle stamp between solved and unsolved on put 'toggle_solution'" do
		forum = create_test_forum(@category, Forum::TYPE_KEYS_BY_TOKEN[:problem])
		topic = publish_topic(create_test_topic(forum, @user))

		put :toggle_solution,
			:id => topic.id

		solved_topic = @account.topics.find_by_id(topic.id)
		solved_topic.stamp_type.should eql Topic::PROBLEMS_STAMPS_BY_TOKEN[:solved]
		response.should redirect_to "support/discussions/topics/#{topic.id}"

		#unsolve a solved topic

		put :toggle_solution,
			:id => solved_topic.id

		solved_topic.reload
		solved_topic.stamp_type.should eql Topic::PROBLEMS_STAMPS_BY_TOKEN[:unsolved]
		response.should redirect_to "support/discussions/topics/#{topic.id}"
	end

	it "should toggle monitor on put 'toggle_monitor'" do
		topic = publish_topic(create_test_topic(@forum, @user))
		new_user = add_new_user(@account)
		log_in(new_user)

		put :toggle_monitor,
			:id => topic.id

		monitorship = topic.monitorships.find_by_user_id(new_user.id)
		monitorship.should be_an_instance_of(Monitorship)
		monitorship.monitorable_id.should eql topic.id
		monitorship.monitorable_type.should eql "Topic"
		monitorship.active.should be_true

		#monitorship should be inactive on unfollow

		put :toggle_monitor,
			:id => topic.id

		monitorship = topic.monitorships.find_by_user_id(new_user.id)
		monitorship.should be_an_instance_of(Monitorship)
		monitorship.monitorable_id.should eql topic.id
		monitorship.monitorable_type.should eql "Topic"
		monitorship.active.should be_false
	end


	it "should vote a topic on put 'like'" do
		topic = publish_topic(create_test_topic(@forum, @user))
		vote_count = topic.user_votes

		put :like,
			:id => topic.id,
			:vote => "for"

		liked_topic = @account.topics.find_by_id(topic.id)
		liked_topic.user_votes.should be_eql(vote_count + 1)
		vote = liked_topic.votes.find_by_user_id(@user.id)
		vote.should be_an_instance_of(Vote)
		vote.voteable_id.should eql topic.id
		vote.voteable_type.should eql "Topic"
		response.should render_template 'support/discussions/topics/_topic_vote.html.erb'

		#----

		put :unlike,
			:id => topic.id,
			:vote => "for"

		unliked_topic = @account.topics.find_by_id(topic.id)
		unliked_topic.user_votes.should be_eql(vote_count)
		vote = unliked_topic.votes.find_by_user_id(@user.id)
		vote.should be_nil
		response.should render_template 'support/discussions/topics/_topic_vote.html.erb'
	end

	it "should render my topics page on get 'my_topics'" do
		get :my_topics

		response.should render_template 'support/discussions/topics/my_topics.portal'
	end

	it "should render users voted partial on get 'users_voted'" do
		topic = publish_topic(create_test_topic(@forum, @user))

		get :users_voted, :id => topic.id

		response.should render_template 'support/discussions/topics/_users_voted.html.erb'
	end

	it "should redirect to support home if portal forums is disabled" do
		topic = publish_topic(create_test_topic(@forum, @user))
		@account.features.hide_portal_forums.create

		get :my_topics
		response.should redirect_to "/support/home"

		topic_title = Faker::Lorem.sentence(1)
		post :create,
		:topic =>
				{:title=> topic_title, 
				:body_html=> "", 
				:forum_id=> @forum.id }
		response.should redirect_to "/support/home"

		get :new
		response.should redirect_to "/support/home"

		put :like, :id => topic.id, :vote => "for"
		response.should redirect_to "/support/home"

		put :unlike, :id => topic.id
		response.should redirect_to "/support/home"

		put :toggle_monitor, :id => topic.id
		response.should redirect_to "/support/home"

		put :monitor, :id => topic.id
		response.should redirect_to "/support/home"

		put :toggle_solution, :id => topic.id
		response.should redirect_to "/support/home"

		get :edit, :id => topic.id
		response.should redirect_to "/support/home"

		get :hit, :id => topic.id
		response.should redirect_to "/support/home"

		get :check_monitor, :id => topic.id
		response.should redirect_to "/support/home"

		get :users_voted , :id => topic.id
		response.should redirect_to "/support/home"

		get :reply, :topic_id => topic.id
		response.should redirect_to "/support/home"

		get :show, :id => topic.id
		response.should redirect_to "/support/home"

		put :update,
			:id => topic.id,
			:topic => {
				:title=> Faker::Lorem.sentence(1), 
				:body_html=>"<p>#{Faker::Lorem.paragraph}</p>"
			}
		response.should redirect_to "/support/home"

		delete :destroy, :id => topic.id
		response.should redirect_to "/support/home"			

		@account.features.hide_portal_forums.destroy
	end


	# it "should lock a topic on put 'update_lock'" do
	# 	topic = publish_topic(create_test_topic(@forum, @user))

	# 	put :update_lock,
	# 		:id => topic.id

	# 	topic.reload
	# 	topic.locked.should be_true
	# 	response.should render_template 'support/discussions/topics'
	# end

	# it "should unlock a locked topic on put 'update_lock'" do
	# 	locked_topic = lock_topic(publish_topic(create_test_topic(@forum, @user)))

	# 	put :update_lock,
	# 		:id => locked_topic.id

	# 	locked_topic.reload
	# 	locked_topic.locked.should be_false
	# 	response.should render_template 'support/discussions/topics'
	# end



end
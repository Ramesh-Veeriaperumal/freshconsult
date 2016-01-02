require 'spec_helper'

describe Discussions::TopicsController do
  	setup :activate_authlogic
  	self.use_transactional_fixtures = false

	before(:all) do
		@category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
	end

	before(:each) do
        @request.env['HTTP_REFERER'] = '/discussions'
	    log_in(@agent)
	end

	after(:all) do
		@category.destroy
	end

	it "should render new page on get 'new'" do
		get :new

		response.should render_template 'discussions/topics/new'
	end

	it "should render edit page on get 'edit'" do
		topic = create_test_topic(@forum, @agent)
		create_test_post(topic)

		get :edit, :id => topic.id

		topic_from_controller = controller.instance_variable_get(:@topic)
		topic_from_controller.should eql topic
		response.should render_template 'discussions/topics/edit'
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
					:sticky => 0,
					:locked => 0 }

		new_topic = @account.topics.find_by_title(topic_title)
		new_topic.forum_id.should eql @forum.id
		new_topic.user_id.should eql @agent.id
		new_topic.account_id.should eql @account.id

		new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
		new_post.topic_id.should eql new_topic.id

		new_post.user_id.should eql @agent.id
		new_post.account_id.should eql @account.id
		Monitorship.count.should eql old_follower_count  1
		Monitorship.last.portal_id.should_not be_nil

		response.should redirect_to "/discussions/topics/#{new_topic.id}"
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

		response.should render_template 'discussions/topics/new'
	end

	it "should render show page on get 'show'" do
		topic = create_test_topic(@forum)
		create_test_post(topic)

		get :show, :id => topic.id

		response.should render_template "discussions/topics/show"
	end

	it "should redirect to discussions page on get 'show' when topic is not available" do
		topic = create_test_topic(@forum)
		topic_id = topic.id
		topic.destroy

		get :show, :id => topic_id

		response.should redirect_to "/discussions"
	end

	it "should deny access on get 'show' when user doesnt have privilege to view forum" do
		topic = create_test_topic(@forum)
		create_test_post(topic)
		agent = add_agent(@account, { :name => Faker::Name.name, 
			                        :email => Faker::Internet.email, 
			                        :active => 1, 
			                        :role => 1, 
			                        :agent => 1,
			                        :role_ids => [@account.roles.find_by_name("Agent").id.to_s],
			                        :ticket_permission => 1})
		agent.privileges = 525315
		agent.save!
		log_in(agent)
		get :show, :id => topic.id

		session["flash"][:notice].should eql I18n.t(:'flash.general.access_denied')
	end

	it "should redirect to support page on get 'show' when logged in by customer" do
		topic = create_test_topic(@forum)
		create_test_post(topic)
		log_in(add_new_user(@account))

		get :show, :id => topic.id

		response.should redirect_to "/support/discussions/topics/#{topic.id}"
	end

	it "should update a topic on put 'update'" do
		topic = create_test_topic(@forum, @agent)
		create_test_post(topic, @agent)
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
		topic.user_id.should eql @agent.id
		topic.account_id.should eql @account.id

		post = @account.posts.find_by_body_html("<p>#{new_post_body}</p>")
		post.topic_id.should eql topic.id
		post.user_id.should eql @agent.id
		post.account_id.should eql @account.id

		response.should redirect_to "/discussions/topics/#{topic.id}"
	end


	it "should unmark post answer when a topic's forum type is changed from a question type to a different type" do
		question_forum = create_test_forum(@category,Forum::TYPE_KEYS_BY_TOKEN[:howto])
		problem_forum = create_test_forum(@category,Forum::TYPE_KEYS_BY_TOKEN[:problem])

		topic = create_test_topic(question_forum)
		post = create_test_post(topic)
		post.toggle_answer
		post.reload
		topic.reload
		post.answer.should eql true
		topic.stamp_type.should eql Topic::QUESTIONS_STAMPS_BY_TOKEN[:answered]

		put :update,
			:id => topic.id,
			:topic =>
					{:forum_id => problem_forum.id}
        
        post.reload
		topic.reload
		post.answer.should eql false
		post.forum_id.should eql problem_forum.id
		topic.stamp_type.should_not eql Topic::QUESTIONS_STAMPS_BY_TOKEN[:answered]
	end

	it "should NOT change post answer when a topic's forum type is changed from a question type to a question type itself" do
		question_forum_old = create_test_forum(@category,Forum::TYPE_KEYS_BY_TOKEN[:howto])
		question_forum_new = create_test_forum(@category,Forum::TYPE_KEYS_BY_TOKEN[:howto])

		topic = create_test_topic(question_forum_old)
		post = create_test_post(topic)
		post.toggle_answer
		post.reload
		topic.reload
		post.answer.should eql true
		topic.stamp_type.should eql Topic::QUESTIONS_STAMPS_BY_TOKEN[:answered]

		put :update,
			:id => topic.id,
			:topic =>
					{:forum_id => question_forum_new.id}
        
        post.reload
		topic.reload
		post.answer.should eql true
		post.forum_id.should eql question_forum_new.id
		topic.stamp_type.should eql Topic::QUESTIONS_STAMPS_BY_TOKEN[:answered]
	end


	it "should not update a topic on put 'update' when message is invalid" do
		topic = create_test_topic(@forum, @agent)
		create_test_post(topic, @agent)

		put :update,
			:id => topic.id,
			:topic =>
					{:title=> "", 
					:body_html=> ""}

		topic.reload
		topic.title.should_not eql ""
		@account.posts.find_by_body_html("").should be_nil

		response.should render_template "discussions/topics/edit"
	end

	it "should delete a topic on delete 'destroy'" do
		topic = create_test_topic(@forum)
		post = create_test_post(topic)

		delete :destroy, :id => topic.id

		@account.topics.find_by_id(topic.id).should be_nil
		@account.posts.find_by_id(post.id).should be_nil
		response.should redirect_to "/discussions/forums/#{@forum.id}"
	end

	it "should render a component partial on 'component'" do
		topic = create_test_topic(@forum)
		post = create_test_post(topic)
		name = :voted_users

		get :component, :id => topic.id, :name => name

		response.should render_template "discussions/topics/components/_#{name}"
	end

	it "should render 404 on 'component' when accessing different partial" do
		topic = create_test_topic(@forum)
		post = create_test_post(topic)

		get :component, :id => topic.id, :name => 'test'
		response.should render_template(:file => "#{Rails.root}/public/404.html")
    expect(response.status).to eql(404)
	end

	it "should lock a topic on put 'update_lock'" do
		topic = create_test_topic(@forum)

		put :toggle_lock,
			:id => topic.id

		topic.reload
		topic.locked.should be_truthy
		response.should redirect_to "/discussions/topics/#{topic.id}"
	end

	it "should unlock a locked topic on put 'update_lock'" do
		locked_topic = lock_topic(create_test_topic(@forum))

		put :toggle_lock,
			:id => locked_topic.id

		locked_topic.reload
		locked_topic.locked.should be_falsey
		response.should redirect_to "/discussions/topics/#{locked_topic.id}"
	end

	it "should render latest reply page on get 'latest_reply'" do
		topic = create_test_topic(@forum, @agent)
		create_test_post(topic, @agent)

		get :latest_reply, :id => topic.id

		response.should render_template 'discussions/topics/latest_reply'
	end

	it "should update stamp of a topic on put 'update_stamp'" do
		forum = create_test_forum(@category, Forum::TYPES[1][2])
		topic = create_test_topic(forum)
		forum_type_symbol = Forum::TYPE_KEYS_BY_TOKEN[Forum::TYPE_SYMBOL_BY_KEY[forum.forum_type]]
		stamp_type = Topic::ALL_TOKENS_FOR_FILTER[forum_type_symbol].keys.sample

		put :update_stamp,
			:id => topic.id,
			:stamp_type => stamp_type

		topic.reload
		topic.stamp_type.should eql stamp_type
		# response.should redirect_to "/discussions/topics/#{topic.id}"
	end
	
	it "should mark delete all the topics when 'destroy_multiple'" do
		topics = []
		5.times do |n|
			topics << create_test_topic(@forum)
		end
		delete :destroy_multiple, :ids => topics.map(&:id), :category_id => @category.id, "forum_id"=> @forum.id
		topics.each do |topic|
			@account.topics.find_by_id(topic.id).should be_nil
		end
	end  

  it "should vote a topic on put 'vote'" do
    request.env["HTTP_ACCEPT"] = "application/javascript"
    topic = create_test_topic(@forum, @agent)
    vote_count = topic.user_votes

    put :vote, :id => topic.id
    liked_topic = @account.topics.find_by_id(topic.id)
    liked_topic.user_votes.should be_eql(vote_count  1)
    vote = liked_topic.votes.find_by_user_id(@agent.id)
    vote.should be_an_instance_of(Vote)
    vote.voteable_id.should eql topic.id
    vote.voteable_type.should eql "Topic"
    response.should render_template 'discussions/topics/vote'

    put :vote, :id => topic.id

    unliked_topic = @account.topics.find_by_id(topic.id)
    unliked_topic.user_votes.should be_eql(vote_count)
    vote = unliked_topic.votes.find_by_user_id(@agent.id)
    vote.should be_nil
    response.should render_template 'discussions/topics/vote'

  end


	describe "User assignment" do 

		before(:all) do 
			@user = add_new_user(@account)
		end

		describe("Only users with admin privilege can create topic on behalf of others") do 

			before(:each) do
				agent = add_agent(@account, { :name => Faker::Name.name, 
					                        :email => Faker::Internet.email, 
					                        :active => 1, 
					                        :role => 1, 
					                        :agent => 1,
					                        :role_ids => [@account.roles.find_by_name("Account Administrator").id.to_s],
					                        :ticket_permission => 1})
				agent.save!
				log_in(agent)
			end

			it "should assign author to topic mentioned by user_id" do
				topic_title = Faker::Lorem.sentence(1)
				post_body = Faker::Lorem.paragraph
				post :create,
					:topic =>
							{:title=> topic_title, 
							:body_html=>"<p>#{post_body}</p>", 
							:forum_id=> @forum.id,
							:sticky => 0,
							:locked => 0,
							:user_id => @user.id}

				new_topic = @account.topics.find_by_title(topic_title)
				new_topic.forum_id.should eql @forum.id
				new_topic.user_id.should eql @user.id
				new_topic.published.should eql true


				new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
				new_post.topic_id.should eql new_topic.id
				new_post.user_id.should eql @user.id
				new_post.published.should eql true
			end

			it "should assign author to topic mentioned by email_id" do 
				topic_title = Faker::Lorem.sentence(1)
				post_body = Faker::Lorem.paragraph
				post :create,
					:topic =>
							{:title=> topic_title, 
							:body_html=>"<p>#{post_body}</p>", 
							:forum_id=> @forum.id,
							:sticky => 0,
							:locked => 0,
							:import_id => 1
							},
					:email => @user.email

				new_topic = @account.topics.find_by_title(topic_title)
				new_topic.forum_id.should eql @forum.id
				new_topic.user_id.should eql @user.id
				new_topic.published.should eql true

				new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
				new_post.topic_id.should eql new_topic.id
				new_post.user_id.should eql @user.id
				new_post.published.should eql true
			end

			it "should assign author to topic mentioned by user_id when both email and user_id is passed" do
				topic_title = Faker::Lorem.sentence(1)
				post_body = Faker::Lorem.paragraph
				user = add_new_user(@account)
				post :create,
					:topic =>
							{:title=> topic_title, 
							:body_html=>"<p>#{post_body}</p>", 
							:forum_id=> @forum.id,
							:sticky => 0,
							:locked => 0,
							:import_id => 1,
							:user_id => user.id
							},
					:email => @user.email
				new_topic = @account.topics.find_by_title(topic_title)
				new_topic.forum_id.should eql @forum.id
				new_topic.user_id.should eql user.id
				new_topic.published.should eql true


				new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
				new_post.topic_id.should eql new_topic.id
				new_post.user_id.should eql user.id
				new_post.published.should eql true
			end
		end


		describe("Users with out admin privilege can't create topic on behalf of others") do

			before(:each) do
				@user = add_new_user(@account)
				@test_agent = add_agent(@account, { :name => Faker::Name.name, 
					                        :email => Faker::Internet.email, 
					                        :active => 1, 
					                        :role => 1, 
					                        :agent => 1,
					                        :role_ids => [@account.roles.find_by_name("Agent").id.to_s],
					                        :ticket_permission => 1})
				@test_agent.save!
				log_in(@test_agent)
			end

			it "should assign current user as author for user_id" do
				topic_title = Faker::Lorem.sentence(1)
				post_body = Faker::Lorem.paragraph
				post :create,
					:topic =>
							{:title=> topic_title, 
							:body_html=>"<p>#{post_body}</p>", 
							:forum_id=> @forum.id,
							:sticky => 0,
							:locked => 0,
							:user_id => @user.id}

				new_topic = @account.topics.find_by_title(topic_title)
				new_topic.forum_id.should eql @forum.id
				new_topic.user_id.should eql @test_agent.id
				new_topic.published.should eql true


				new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
				new_post.topic_id.should eql new_topic.id
				new_post.user_id.should eql @test_agent.id
				new_post.published.should eql true
			end

			it"should assign current user as author for email" do 
				topic_title = Faker::Lorem.sentence(1)
				post_body = Faker::Lorem.paragraph
				post :create,
					:topic =>
							{:title=> topic_title, 
							:body_html=>"<p>#{post_body}</p>", 
							:forum_id=> @forum.id,
							:sticky => 0,
							:locked => 0,
							:import_id => 1
							},
					:email => @user.email

				new_topic = @account.topics.find_by_title(topic_title)
				new_topic.forum_id.should eql @forum.id
				new_topic.user_id.should eql @test_agent.id
				new_topic.published.should eql true

				new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
				new_post.topic_id.should eql new_topic.id
				new_post.user_id.should eql @test_agent.id
				new_post.published.should eql true
			end
			it "should assign current user as author for user_id and email_id" do
				topic_title = Faker::Lorem.sentence(1)
				post_body = Faker::Lorem.paragraph
				user = add_new_user(@account)
				post :create,
					:topic =>
							{:title=> topic_title, 
							:body_html=>"<p>#{post_body}</p>", 
							:forum_id=> @forum.id,
							:sticky => 0,
							:locked => 0,
							:import_id => 1,
							:user_id => user.id
							},
					:email => @user.email
				new_topic = @account.topics.find_by_title(topic_title)
				new_topic.forum_id.should eql @forum.id
				new_topic.user_id.should eql @test_agent.id
				new_topic.published.should eql true

				new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
				new_post.topic_id.should eql new_topic.id
				new_post.user_id.should eql @test_agent.id
				new_post.published.should eql true
			end
		end
	end

	describe "Topic creation from ticket" do

		it "should have ticket assosiation when created from ticket" do
			ticket = create_ticket({:status => 2 })
			post :create,
				{ :topic =>
						{:title=> ticket.subject, 
						:body_html=> ticket.description_html, 
						:forum_id=> @forum.id,
						:sticky => 0,
						:locked => 0,
						:display_id => ticket.display_id
					},
					:post => {}
				}
			topic = @account.topics.find_by_title(ticket.subject)
			topic.ticket.should_not be_nil
			topic.ticket.id.should be_eql(ticket.id)
      topic.user_id.should be_eql(ticket.requester_id)
      topic.posts.first.user_id.should be_eql(ticket.requester_id)
      topic.published?.should be_eql(true)
      topic.posts.first.published?.should be_eql(true)
		end

		it "should redirect to topic page when topic is already created from ticket for Topic New page" do
			ticket = create_ticket({:status => 2 })
			post :create,
				{ :topic =>
						{:title=> ticket.subject,
						:body_html=> ticket.description_html, 
						:forum_id=> @forum.id,
						:sticky => 0,
						:locked => 0,
						:display_id => ticket.display_id
					},
					:post => {}
	      }
			topic = @account.topics.find_by_title(ticket.subject)
			get :new, :ticket_id => ticket.display_id
			response.should redirect_to discussions_topic_path(ticket.topic)
		end

		it "should redirect to topic page when topic is already created from ticket for Topic Create action" do
			ticket = create_ticket({:status => 2 })
			post :create,
				{ :topic =>
						{:title=> ticket.subject,
						:body_html=> ticket.description_html, 
						:forum_id=> @forum.id,
						:sticky => 0,
						:locked => 0,
						:display_id => ticket.display_id
					},
					:post => {}
	      }
			topic = @account.topics.find_by_title(ticket.subject)
      
      post :create,
				{ :topic =>
						{:title=> ticket.subject,
						:body_html=> ticket.description_html, 
						:forum_id=> @forum.id,
						:sticky => 0,
						:locked => 0,
						:display_id => ticket.display_id
					},
					:post => {}
	      }
			response.should redirect_to discussions_topic_path(ticket.topic)
		end

	end
end
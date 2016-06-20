require 'spec_helper'

describe Discussions::PostsController do
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


	it "should create a post on 'create'" do
		post_body = Faker::Lorem.paragraph
		old_follower_count = Monitorship.count

	    post :create, :topic_id => @topic.id, :post => {
											    :body_html => "<div>#{post_body}</div>"					
											    }

		new_post = @account.posts.find_by_body_html("<div>#{post_body}</div>")
		new_post.should be_instance_of(Post)
		new_post.user_id.should be_eql @agent.id
		new_post.topic_id.should be_eql @topic.id
		new_post.account_id.should be_eql @account.id
		
		Monitorship.count.should eql old_follower_count + 1
		Monitorship.last.portal_id.should_not be_nil
		response.should redirect_to "/discussions/topics/#{@topic.id}/page/last#post_#{new_post.id}"
	end

	it "should not create a post on 'create' when message is invalid" do
		post :create, :topic_id => @topic.id, :post => {
											    :body_html => ''						
											    }

		@account.posts.find_by_body_html('').should be_nil
        response.should redirect_to '/discussions'
	end

	it "should go to the edit page" do
		post = create_test_post(@topic)

		get :edit, :id => post.id, :topic_id => @topic.id

		response.should render_template "discussions/posts/edit"
	end

	it "should update a post on 'update'" do
		post_body = Faker::Lorem.paragraph
		post = create_test_post(@topic)

	    put :update, :id => post.id, :topic_id => @topic.id, :post => {
											    :body_html => "<div>#{post_body}</div>"					
											    }

		post.reload
		post.body_html.should be_eql("<div>#{post_body}</div>")
	end

	it "should not update a post on 'update' when message is invalid" do
		post = create_test_post(@topic)

		put :update, :id => post.id, :topic_id => @topic.id, :post => {
											    :body_html => ""					
											    }
		post.reload
		post.body_html.should_not eql ""
        response.should redirect_to '/discussions'
	end

	it "should destroy a post on 'destroy'" do
		post = create_test_post(@topic)

	    delete :destroy, :id => post.id, :topic_id => @topic.id

	    @account.posts.find_by_id(post.id).should be_nil
	end


	it "should mark a post as answer on 'toggle_answer'" do
		topic = create_test_topic(@forum)
		post = create_test_post(topic)

		put :toggle_answer, :id => post.id, :topic_id => topic.id

		post.reload
		topic.reload
		post.answer.should be_eql true
		topic.stamp_type.should be_eql(Topic::QUESTIONS_STAMPS_BY_TOKEN[:answered])
		topic.answer.should be_eql(post)
	end

	it "should unmark a post as answer on 'toggle_answer'" do
		topic = create_test_topic(@forum)
		post = mark_as_answer(create_test_post(topic))

		put :toggle_answer, :id => post.id, :topic_id => topic.id

		post.reload
		topic.reload
		post.answer.should be_eql false
		topic.stamp_type.should be_eql(Topic::QUESTIONS_STAMPS_BY_TOKEN[:unanswered])
		topic.answer.should be_nil
	end

	it "should render best answer on 'best_answer'" do
		post = mark_as_answer(create_test_post(@topic))

	    put :best_answer, :id => post.id, :topic_id => @topic.id

	    response.should render_template "discussions/posts/best_answer"
	end

	describe "User assignment" do

		before(:all) do 
			@user = add_new_user(@account)
		end

		describe("Users with admin privilege can post on behalf of others") do 
			
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

			it "should assign author to post mentioned by user_id" do
				post_body = Faker::Lorem.paragraph
				post :create, :topic_id => @topic.id,
					:post =>
							{:body_html=>"<p>#{post_body}</p>", 
							:user_id => @user.id}

				new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
				new_post.topic_id.should eql @topic.id
				new_post.user_id.should eql @user.id
				new_post.published.should eql true
			end

			it "should assign author to post mentioned by email_id" do
				post_body = Faker::Lorem.paragraph
				post :create, :topic_id => @topic.id,
					:post => {
					 			:body_html=>"<p>#{post_body}</p>", 
					 			:user_id => @user.id
					 		 },
					:email => @user.email

				new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
				new_post.topic_id.should eql @topic.id
				new_post.user_id.should eql @user.id
				new_post.published.should eql true
			end

			it "should assign author to post mentioned by user_id when both email and user_id is passed" do
				post_body = Faker::Lorem.paragraph
				user = add_new_user(@account)
				post :create, :topic_id => @topic.id,
					:post =>
							{ 
								:body_html=>"<p>#{post_body}</p>", 
								:import_id => 1,
								:user_id => user.id
							},
					:email => @user.email

				new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
				new_post.topic_id.should eql @topic.id
				new_post.user_id.should eql user.id
				new_post.published.should eql true
			end

		end

		describe("Users without admin privilege cannot post on behalf of others") do 

			before(:each) do
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
				post_body = Faker::Lorem.paragraph
				post :create, :topic_id => @topic.id,
					:post =>
							{
								:body_html=>"<p>#{post_body}</p>", 
								:user_id => @user.id
							}

				new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
				new_post.topic_id.should eql @topic.id
				new_post.user_id.should eql @test_agent.id
				new_post.published.should eql true
			end

			it "should assign current user as author for email" do 
				post_body = Faker::Lorem.paragraph
				post :create, :topic_id => @topic.id,
					:post =>
							{ 
								:body_html=>"<p>#{post_body}</p>", 
								:import_id => 1
							},
					:email => @user.email

				new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
				new_post.topic_id.should eql @topic.id
				new_post.user_id.should eql @test_agent.id
				new_post.published.should eql true
			end

			it "should assign current user as author for user_id and email_id" do
				post_body = Faker::Lorem.paragraph
				user = add_new_user(@account)
				post :create, :topic_id => @topic.id,
					:post =>
							{
								:body_html=>"<p>#{post_body}</p>", 
								:import_id => 1,
								:user_id => user.id
							},
					:email => @user.email

				new_post = @account.posts.find_by_body_html("<p>#{post_body}</p>")
				new_post.topic_id.should eql @topic.id
				new_post.user_id.should eql @test_agent.id
				new_post.published.should eql true
			end
		end
	end
end
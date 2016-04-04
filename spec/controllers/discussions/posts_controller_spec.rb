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


end
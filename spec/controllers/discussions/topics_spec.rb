require File.expand_path("#{File.dirname(__FILE__)}/../../spec_helper")

describe TopicsController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:each) do
		@category = create_test_category
		@question_forum = create_test_forum(@category,Forum::TYPE_KEYS_BY_TOKEN[:howto])
		@problem_forum = create_test_forum(@category,Forum::TYPE_KEYS_BY_TOKEN[:problem])
    @request.env['HTTP_REFERER'] = '/categories'
	  log_in(@user)
	end

	after(:all) do
		@category.destroy
	end

	describe "Setting Default stamps for the Topics" do
		it "should set stamp_type as unanswered when Question type topic is created" do
			topic = create_test_topic(@question_forum)
			topic.reload
			topic.stamp_type.should eql Topic::QUESTIONS_STAMPS_BY_TOKEN[:unanswered]
		end
		it "should set stamp_type as unsolved when Problem type topic is created" do
			topic =  create_test_topic(@problem_forum)
			topic.reload
			topic.stamp_type.should eql Topic::PROBLEMS_STAMPS_BY_TOKEN[:unsolved]
		end
	end

	describe "Marking/Unmarking a post as answer" do
		it "should set stamp_type as answered when one of the post is marked as answer" do
			topic = create_test_topic(@question_forum)
			post = create_test_post(topic)
			post.toggle_answer
			topic.reload
			topic.stamp_type.should eql Topic::QUESTIONS_STAMPS_BY_TOKEN[:answered]
		end
		it "should unmark if any answer exist when one of the post is marked as answer" do
			topic = create_test_topic(@question_forum)
			first_post = create_test_post(topic)
			first_post.toggle_answer
			# stamp_type of the topic should be set as answered
			second_post = create_test_post(topic)
			second_post.toggle_answer
			first_post.reload
			first_post.answer.should eql false
			topic.reload
			topic.stamp_type.should eql Topic::QUESTIONS_STAMPS_BY_TOKEN[:answered]
		end
		it "should set stamp_type as unanswered when answer is unmarked" do
			topic = create_test_topic(@question_forum)
			post = create_test_post(topic)
			post.toggle_answer
			post.toggle_answer
			topic.reload
			topic.stamp_type.should eql Topic::QUESTIONS_STAMPS_BY_TOKEN[:unanswered]
		end
	end

	describe "Marking a topic as solved" do
		it "should set stamp_type as solved" do
			topic = create_test_topic(@problem_forum)
			topic.toggle_solved_stamp
			topic.reload
			topic.stamp_type.should eql Topic::PROBLEMS_STAMPS_BY_TOKEN[:solved]
		end
	end

	describe "Bulk delete of topics" do
		it "should mark delete all the topics when 'destroy_multiple'" do
			topics = []
			5.times do |n|
				topics << create_test_topic(@question_forum)
			end
			delete :destroy_multiple, :ids => topics.map(&:id), :category_id => @category.id, "forum_id"=> @question_forum.id
			topics.each do |topic|
				@account.topics.find_by_id(topic.id).should be_nil
			end
		end
	end
end
require 'spec_helper'

describe Discussions::TopicsController do

  self.use_transactional_fixtures = false
  include APIAuthHelper

  before(:all) do
    @category = create_test_category
		@forum = create_test_forum(@category)
		@topic = create_test_topic(@forum)
  end

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end
	
	it "should update stamp of a topic on put 'update_stamp'" do
		forum = create_test_forum(@category, Forum::TYPES[1][2])
		topic = create_test_topic(forum)
		forum_type_symbol = Forum::TYPE_KEYS_BY_TOKEN[Forum::TYPE_SYMBOL_BY_KEY[forum.forum_type]]
		stamp_type = Topic::ALL_TOKENS_FOR_FILTER[forum_type_symbol].keys.sample

		put :update_stamp,
			:id => topic.id,
			:stamp_type => stamp_type, :format => 'json'

		topic.reload
		topic.stamp_type.should eql stamp_type
		response.status.should eql "200 OK"
	end
	
	it "should update stamp of a topic on put 'update_stamp' with valid posts" do
		topic = create_test_topic(@forum) # This is a question forum
		stamp_type = Topic::QUESTIONS_STAMPS[0][2]
		post = create_test_post(topic)
		post.update_attributes(:answer => 1)

		put :update_stamp,
			:id => topic.id,
			:stamp_type => stamp_type, :format => 'json'

		topic.reload
		topic.stamp_type.should eql stamp_type
		response.status.should eql "200 OK"
	end
	
	it "should not update stamp of a topic on put 'update_stamp' with invalid stamp_type" do
		topic = create_test_topic(@forum) # This is a question forum
		initial_stamp_type = topic.stamp_type
		stamp_type = Topic::IDEAS_STAMPS[0][2]

		put :update_stamp,
			:id => topic.id,
			:stamp_type => stamp_type, :format => 'json'

		@response.body.should eql "[[\"stamp_type\",\"is not valid\"]]"
		topic.reload
		topic.stamp_type.should eql initial_stamp_type
		response.status.should eql "400 Bad Request"
	end
	
	it "should not update stamp of a topic on put 'update_stamp' with invalid posts" do
		topic = create_test_topic(@forum) # This is a question forum
		initial_stamp_type = topic.stamp_type
		stamp_type = Topic::QUESTIONS_STAMPS[0][2]

		put :update_stamp,
			:id => topic.id,
			:stamp_type => stamp_type, :format => 'json'

		@response.body.should eql "[[\"stamp_type\",\"is not valid\"]]"
		topic.reload
		topic.stamp_type.should eql initial_stamp_type
		response.status.should eql "400 Bad Request"
	end

end

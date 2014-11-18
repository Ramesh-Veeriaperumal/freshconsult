require 'spec_helper'

RSpec.describe Support::DiscussionsController do

  self.use_transactional_fixtures = false

  before(:all) do
    @category = create_test_category
    @forum = create_test_forum(@category)
    @topic = create_test_topic(@forum)
    @user = add_new_user(@account)
    monitor_topic(@topic)
  end

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should be able to fetch user monitored topics." do
    get :user_monitored, { :user_id => @user.id, :format => 'json' }, :content_type => 'application/json'
    result = parse_json(response)
    expected = (response.status === 200) && (compare(result.first["topic"].keys, APIHelper::TOPIC_ATTRIBS-["account_id"], {}).empty?)
    expected.should be(true)
  end

  it "should be able to fetch user monitored topics for other users." do
    @test_user = add_new_user(@account)
    get :user_monitored, { :user_id => @test_user.id, :format => 'json' }, :content_type => 'application/json'
    result = parse_json(response)
    expected = (response.status === 200) && result.empty?
    expected.should be(true)
  end

end
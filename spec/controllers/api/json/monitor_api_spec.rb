require 'spec_helper'

RSpec.describe MonitorshipsController do

  self.use_transactional_fixtures = false

  before(:all) do
    @category = create_test_category
    @forum = create_test_forum(@category)
    @topic = create_test_topic(@forum)
  end

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should be able to monitor/follow a forum topic" do
    post :toggle, {:id => @topic.id, :object => "topic", :type => "follow", :format => 'json'}, :content_type => 'application/json'
    response.status.should === 200
  end
  it "should be able to unmonitor/unfollow a forum topic" do
    post :toggle, {:id => @topic.id, :object => "topic", :type => "unfollow",:format => 'json'}, :content_type => 'application/json'
    response.status.should === 200
  end

  it "should be able to view monitoring status of an unfollowed forum" do
    get :is_following, {:id => @forum.id, :object => "forum", :format => 'json'}
    result = parse_json(response)
    response.status.should === 200 && result==[]
  end

  it "should be able to view monitoring status of a followed forum" do
    monitor_forum(@forum, User.current)
    get :is_following, {:id => @forum.id, :object => "forum", :format => 'json', :user_id => User.current.id}
    result = parse_json(response)
    response.status.should === 200 && compare(result['monitorship'].keys, APIHelper::MONITOR_ATTRIBS,{}).empty?
  end

  it "should be able to view monitoring status of a forum topic" do
    get :is_following, {:id => @topic.id, :object => "topic", :format => 'json'}
    result = parse_json(response)
    response.status.should === 200 && compare(result['monitorship'].keys, APIHelper::MONITOR_ATTRIBS,{}).empty?
  end

 end

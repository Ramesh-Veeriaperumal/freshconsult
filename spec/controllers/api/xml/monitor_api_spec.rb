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

  #adding xml api too here, to avoid an unnecessary file
  it "should be able to monitor/follow a forum topic" do
    post :toggle, {:id => @topic.id, :object => "topic", :type => "follow", :format => 'xml'}, :content_type => 'application/xml'
    response.status.should === 200
  end
  it "should be able to unmonitor/unfollow a forum topic" do
    post :toggle, {:id => @topic.id, :object => "topic", :type => "unfollow", :format => 'xml'}, :content_type => 'application/xml'
    response.status.should === 200
  end

 end

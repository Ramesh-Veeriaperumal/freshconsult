require 'spec_helper'

describe MonitorshipsController do

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

  it "should be able to monitor/follow a forum topic" do
    post :toggle, {:id => @topic.id, :object => "topic", :type => "follow", :format => 'json'}, :content_type => 'application/json'
    response.status.should === 200
  end
  it "should be able to unmonitor/unfollow a forum topic" do
    post :toggle, {:id => @topic.id, :object => "topic", :type => "unfollow",:format => 'json'}, :content_type => 'application/json'
    response.status.should === 200
  end

 end

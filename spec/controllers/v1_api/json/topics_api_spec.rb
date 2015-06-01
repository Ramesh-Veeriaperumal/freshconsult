require 'spec_helper'

RSpec.describe TopicsController do

  self.use_transactional_fixtures = false

  before(:all) do
    @category = create_test_category
    @forum = create_test_forum(@category)
  end

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  after(:all) do
    @category.destroy
  end


  it "should be able to create a forum topic" do
    params = topic_api_params
    params.merge!(:category_id => @category.id,:forum_id=>@forum.id)
    post :create, params.merge!(:format => 'json'), :content_type => 'application/json'
    result = parse_json(response)
    expected = (response.status === 200) && (compare(result["topic"].keys,APIHelper::TOPIC_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  it "should be able to update a forum topic" do
    @topic = create_test_topic(@forum)
    params = topic_api_params
    params.merge!(:id=>@topic.id,:category_id => @category.id,:forum_id=>@forum.id)
    put :update, params.merge!(:format => 'json'), :content_type => 'application/json'
    response.status.should === 200
  end
  it "should be able to view a forum topic" do
    @topic = create_test_topic(@forum)
    params = {:id=>@topic.id,:category_id => @category.id,:forum_id=>@forum.id}
    get :show, params.merge!(:format => 'json')
    result = parse_json(response)
    expected = (response.status === 200) && (compare(result["topic"].keys-["posts"],APIHelper::TOPIC_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  it "should be able to delete a forum topic" do
    @topic = create_test_topic(@forum)
    params = {:id=>@topic.id,:category_id => @category.id,:forum_id=>@forum.id}
    delete :destroy, params.merge!(:format => 'json')
    response.status.should === 200
  end


  def topic_api_params
    {
      "topic"=> {
        "sticky"=>0, 
        "locked"=>0,
        "title"=>Faker::Lorem.words(rand(2..6)),
        "body_html"=>Faker::Lorem.paragraph
      }
    }
  end

end
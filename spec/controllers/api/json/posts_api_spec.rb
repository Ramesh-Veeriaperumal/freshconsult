require 'spec_helper'

describe PostsController do

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

  after(:all) do
    @category.destroy
  end


  it "should be able to create a forum post" do
    params = post_api_params
    params.merge!(:category_id => @category.id,:forum_id=>@forum.id,:topic_id=>@topic.id)
    post :create, params.merge!(:format => 'json'), :content_type => 'application/json'
    result = parse_json(response)
    expected = (response.status === "201 Created") && (compare(result["post"].keys,APIHelper::POST_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  it "should be able to update a forum post" do
    @post = create_test_post(@topic)
    params = post_api_params
    params.merge!(:topic_id=>@topic.id,:category_id => @category.id,:forum_id=>@forum.id,:id=>@post.id)
    put :update, params.merge!(:format => 'json'), :content_type => 'application/json'
    response.status.should === "200 OK"
  end
  it "should be able to delete a forum post" do
    @post = create_test_post(@topic)
    params = {:topic_id=>@topic.id,:category_id => @category.id,:forum_id=>@forum.id,:id=>@post.id}
    delete :destroy, params.merge!(:format => 'json')
    response.status.should === "200 OK"
  end


  def post_api_params
    {
     "post" => { 
        "body_html" => Faker::Lorem.paragraph
       }
    }
  end



end
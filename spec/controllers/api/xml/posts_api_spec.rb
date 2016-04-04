require 'spec_helper'

RSpec.describe PostsController do

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

  after(:all) do
    @category.destroy
  end


  it "should be able to create a forum post" do
    params = post_api_params
    params.merge!(:category_id => @category.id,:forum_id=>@forum.id,:topic_id=>@topic.id)
    post :create, params.merge!(:format => 'xml'), :content_type => 'application/xml'
    result = parse_xml(response)
    expected = (response.status === 200) && (compare(result["post"].keys,APIHelper::POST_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  it "should be able to update a forum post" do
    @post = create_test_post(@topic)
    params = post_api_params
    params.merge!(:topic_id=>@topic.id,:category_id => @category.id,:forum_id=>@forum.id,:id=>@post.id)
    put :update, params.merge!(:format => 'xml'), :content_type => 'application/xml'
    response.status.should === 200
  end
  it "should be able to delete a forum post" do
    @post = create_test_post(@topic)
    params = {:topic_id=>@topic.id,:category_id => @category.id,:forum_id=>@forum.id,:id=>@post.id}
    delete :destroy, params.merge!(:format => 'xml')
    response.status.should === 200
  end


  def post_api_params
    {
     "post" => { 
        "body_html" => Faker::Lorem.paragraph
       }
    }
  end

end
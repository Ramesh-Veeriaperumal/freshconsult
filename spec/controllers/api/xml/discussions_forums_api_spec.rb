require 'spec_helper'

describe Discussions::ForumsController do

  self.use_transactional_fixtures = false
  include APIAuthHelper

  before(:all) do
    @category = create_test_category
  end

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should be able to create a forum within a category" do
    params = forum_api_params
    post :create, params.merge!(:format => 'xml'), :content_type => 'application/xml'
    result = parse_xml(response)
    expected = (response.status === "200 OK") && (compare(result["forum"].keys,APIHelper::FORUM_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

  it "should be able to update a forum" do
    test_forum = create_test_forum(@category)
    put :update, { :id => test_forum.id, :forum => {:description => Faker::Lorem.paragraph }, :format => 'xml'}
    response.status.should === "200 OK"
  end

  it "should be able to view a forum" do
    test_forum = create_test_forum(@category)
    get :show, { :id => test_forum.id, :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status === "200 OK") && (compare(result["forum"].keys-["topics"],APIHelper::FORUM_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

  it "should be able to delete a forum " do
    test_forum = create_test_forum(@category)
    delete :destroy, { :id => test_forum.id,  :format => 'xml'}
    response.status.should === "200 OK"
  end
  
  #negative condition check.
  it "should not create a forum  without a name" do
    post :create, {:forum=> { :description=>Faker::Lorem.paragraph, :forum_type=>2,
          :forum_visibility=>1, :forum_category_id => @category.id}, :format => 
    'json'}, :content_type => 'application/xml'
    response.status.should =~ /406 Not Acceptable/
  end

  def forum_api_params
    { :forum => {
        :description=>Faker::Lorem.paragraph,
        :forum_type=>2,
        :forum_visibility=>1,
        :forum_category_id => @category.id,
        :name=>Faker::Lorem.words(rand(2..6))
      }
    }
  end


end

require 'spec_helper'

describe DiscussionsController do

  self.use_transactional_fixtures = false
  include APIAuthHelper

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should be able to create a forum category" do
    params = create_forum_category
    post :create, params.merge!(:format => 'xml'), :content_type => 'application/xml'
    result = parse_xml(response)
    expected = (response.status === "201 Created")  && (compare(result["forum_category"].keys,APIHelper::FORUM_CATEGORY_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  
  it "should be able to update a forum category" do
    forum_category = create_test_category
    put :update, { :id => forum_category.id, :forum_category => {:description => Faker::Lorem.paragraph }, :format => 'xml'}
    response.status.should === "200 OK"
  end

  it "should be able to view a forum category" do
    forum_category = create_test_category
    get :show, { :id => forum_category.id, :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status === "200 OK") &&  (compare(result["forum_category"].keys-["forums"],APIHelper::FORUM_CATEGORY_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

  #negative condition check.
  it "should not create a forum category without a name" do
    post :create, {:forum_category => { :description=>Faker::Lorem.paragraph },:format => 
    'json'}, :content_type => 'application/xml'
    #currently no error handling for json. change this once its implemented.
    response.status.should =~ /406 Not Acceptable/
  end

    def create_forum_category
      { :forum_category=> {:name => Faker::Lorem.words(10).join(" "),
          :description => Faker::Lorem.paragraph }
      }
    end


end

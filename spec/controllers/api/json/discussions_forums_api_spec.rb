require 'spec_helper'

RSpec.describe Discussions::ForumsController do

  self.use_transactional_fixtures = false

  before(:all) do
    @category = create_test_category
  end

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should be able to create a forum within a category" do
    params = forum_api_params
    post :create, params.merge!(:format => 'json'), :content_type => 'application/json'
    result = parse_json(response)
    expected = (response.status === 201) && (compare(result["forum"].keys,APIHelper::FORUM_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

  it "should be able to update a forum" do
    test_forum = create_test_forum(@category)
    put :update, { :id => test_forum.id, :forum => {:description => Faker::Lorem.paragraph }, :format => 'json'}
    response.status.should === 200
  end

  it "should be able to view a forum" do
    test_forum = create_test_forum(@category)
    get :show, { :id => test_forum.id, :format => 'json'}
    result = parse_json(response)
    expected = (response.status === 200) && (compare(result["forum"].keys-["topics"],APIHelper::FORUM_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

  it "should be able to delete a forum " do
    test_forum = create_test_forum(@category)
    delete :destroy, { :id => test_forum.id, :format => 'json'}
    response.status.should === 200
  end
  
  #negative condition check.
  it "should not create a forum without a name" do
    post :create, {:forum=> { :description=>Faker::Lorem.paragraph, :forum_type=>2,
          :forum_visibility=>1, :forum_category_id => @category.id },:format => 
    'json'}, :content_type => 'application/json'
    #currently no error handling for json. change this once its implemented.
    response.status.should === 406
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

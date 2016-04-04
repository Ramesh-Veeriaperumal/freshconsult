require 'spec_helper'

RSpec.describe DiscussionsController do

  self.use_transactional_fixtures = false

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should be able to create a forum category" do
    params = create_forum_category
    post :create, params.merge!(:format => 'json'), :content_type => 'application/json'
    result = parse_json(response)
    expected = (response.status === 201)  && (compare(result["forum_category"].keys,APIHelper::FORUM_CATEGORY_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

  it "should be able to update a forum category" do
    forum_category = create_test_category
    put :update, { :id => forum_category.id, :forum_category => {:description => Faker::Lorem.paragraph }, :format => 'json'}
    response.status.should === 200
  end

  it "should be able to view a forum category" do
    forum_category = create_test_category
    get :show, { :id => forum_category.id, :format => 'json'}
    result = parse_json(response)
    expected = (response.status === 200) &&  (compare(result["forum_category"].keys-["forums"],APIHelper::FORUM_CATEGORY_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  
  #negative condition check.
  it "should not create a forum category without a name" do
    post :create, {:forum_category => { :description=>Faker::Lorem.paragraph },:format => 
    'json'}, :content_type => 'application/json'
    #currently no error handling for json. change this once its implemented.
    response.status.should === 406
  end

  it "should match discussion category paths to appropriate discussion actions" do
    assert_recognizes({ controller: 'discussions', action: 'create', format: 'json'}, {path: '/discussions/categories.json', method: :post })
    assert_recognizes({ controller: 'discussions', action: 'destroy', id: '1', format: 'json'}, { path: 'discussions/categories/1.json', method: :delete })
    assert_recognizes({ controller: 'discussions', action: 'update', id: '1', format: 'json'}, { path: 'discussions/categories/1.json', method: :put })
    assert_recognizes({ controller: 'discussions', action: 'show', id: '1', format: 'json' }, { path: 'discussions/categories/1.json', method: :get })
  end

    def create_forum_category
      { :forum_category=> {:name => Faker::Lorem.words(10).join(" "),
          :description => Faker::Lorem.paragraph }
      }
    end


end

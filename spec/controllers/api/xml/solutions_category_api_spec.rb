require 'spec_helper'

RSpec.describe Solution::CategoriesController do

  self.use_transactional_fixtures = false


  before(:all) do
    @user = create_dummy_customer
  end


  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should be able to create a solution category" do
    params = solution_category_api_params
    post :create, params.merge!(:format => 'xml'), :content_type => 'application/xml'
    result = parse_xml(response)
    expected = (response.status === 201)  && (compare(result["solution_category"].keys,APIHelper::SOLUTION_CATEGORY_ATTRIBS,{}).empty?)
    expected.should be(true)

  end
  it "should be able to update a solution category" do
    solution_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    put :update, { :id => solution_category.id, :solution_category => {:description => Faker::Lorem.paragraph }, :format => 'xml'}
    result = parse_xml(response)
    # this is returing 201 for update, change it once fixed
    response.status.should === 201
  end
  it "should be able to view a solution category" do
    solution_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    get :show, { :id => solution_category.id, :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status === 200) &&  (compare(result["solution_category"].keys-["folders"],APIHelper::SOLUTION_CATEGORY_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  it "should be able to view all solution categories" do
    solution_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    solution_category_2 = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    get :index, {:format => 'xml'}
    result = parse_xml(response)
    expected = (response.status === 200)  && (compare(result["solution_categories"].first.keys-["folders"],APIHelper::SOLUTION_CATEGORY_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  it "should be able to delete a solution category" do
    solution_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    delete :destroy, { :id => solution_category.id, :format => 'xml'}
    expected = (response.status === 200)
    expected.should be(true)
  end
  #negative condition check.
  it "should not create a forum solution without a name" do
    post :create, {:solution_category => { :description=>Faker::Lorem.paragraph },:format => 
    'xml'}, :content_type => 'application/xml'
    #currently no error handling for xml. change this once its implemented.
    response.status.should === 422
  end

    def solution_category_api_params
      { :solution_category=> {:name => Faker::Lorem.words(10).join(" "),
          :description => Faker::Lorem.paragraph }
      }
    end


end

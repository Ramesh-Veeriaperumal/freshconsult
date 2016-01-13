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
    post :create, params.merge!(:format => 'json'), :content_type => 'application/json'
    result = parse_json(response)

    expect(response.status).to be_eql(201)
    expect(assert_array(result["category"].keys, APIHelper::SOLUTION_CATEGORY_ATTRIBS)).to be_truthy
  end

  it "should be able to update a solution category" do
    solution_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    put :update, { :id => solution_category.id, :solution_category => {:description => Faker::Lorem.paragraph }, :format => 'json'}
    
    expect(response.status).to be_eql(200)
  end

  it "should be able to view a solution category" do
    solution_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )

    get :show, { :id => solution_category.id, :format => 'json'}
    result = parse_json(response)

    expect(response.status).to be_eql(200)
    expect(assert_array(result["category"].keys-["folders"], APIHelper::SOLUTION_CATEGORY_ATTRIBS)).to be_truthy
  end

  it "should be able to view all solution categories" do
    solution_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    solution_category_2 = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    
    get :index, {:format => 'json'}
    result = parse_json(response)

    expect(response.status).to be_eql(200)
    expect(assert_array(result.first["category"].keys-["folders"], APIHelper::SOLUTION_CATEGORY_ATTRIBS)).to be_truthy
  end

  it "should be able to delete a solution category" do
    solution_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    delete :destroy, { :id => solution_category.id, :format => 'json'}
    expect(response.status).to be_eql(200)
  end

  #negative condition check.
  it "should not create a forum solution without a name" do
    post :create, {:solution_category => { :description=>Faker::Lorem.paragraph },:format => 
    'json'}, :content_type => 'application/json'
    #currently no error handling for json. change this once its implemented.
    expect(response.status).to be_eql(422)
  end

    def solution_category_api_params
      { :solution_category=> {:name => Faker::Lorem.words(10).join(" "),
          :description => Faker::Lorem.paragraph }
      }
    end


end

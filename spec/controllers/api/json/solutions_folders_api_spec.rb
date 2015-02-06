require 'spec_helper'

describe Solution::FoldersController do

  self.use_transactional_fixtures = false
  include APIAuthHelper


  before(:all) do
    @user = create_dummy_customer
    @solution_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    @new_company = Factory.build(:company, :name => Faker::Name.name)
    @new_company.save
    @new_company.reload
  end


  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should be able to create a solution folder" do
    params = solution_folder_api_params
    post :create, params.merge!(:category_id=>@solution_category.id,:format => 'json'), :content_type => 'application/json'
    result = parse_json(response)
    expected = (response.status === "201 Created") && (compare(result["folder"].keys,APIHelper::SOLUTION_FOLDER_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  it "should be able to update a solution folder" do
    @test_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @solution_category.id } ) 
    put :update, { :id => @test_folder.id, :category_id=>@solution_category.id, :solution_folder => {:description => Faker::Lorem.paragraph }, :format => 'json'}
    response.status.should === "200 OK"
  end
  it "should be able to view a solution folder" do
    @test_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @solution_category.id } )
    get :show, { :category_id => @solution_category.id, :id=>@test_folder.id, :format => 'json'}
    result = parse_json(response)

    expected = (response.status === "200 OK") &&  (compare(result["folder"].keys-["articles"],APIHelper::SOLUTION_FOLDER_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  it "should be able to delete a solution folder" do
    @test_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @solution_category.id } )
    delete :destroy, { :category_id => @solution_category.id, :id=>@test_folder.id, :format => 'json'}
    response.status.should === "200 OK"
  end

  it "should be able to create a solution folder with visibility being selected companies" do
    params = solution_folder_params_with_company_visibility
    post :create, params.merge!(:category_id=>@solution_category.id,:format => 'json'), :content_type => 'application/json'
    result = parse_json(response)
    expected = (response.status === "201 Created") && (compare(result["folder"].keys,APIHelper::SOLUTION_FOLDER_ATTRIBS,{}).empty?)
    customer_id = @account.folders.find_by_name(params["solution_folder"]["name"] ).customer_folders.first.customer.id 
    expected.should be(true)
    customer_id.should be(@new_company.id)
  end

  def solution_folder_api_params
    {
      "solution_folder"=>{
        "name"=>Faker::Lorem.sentence(3), 
        "visibility"=>1, 
        "description"=>Faker::Lorem.sentence(3)
      }
    } 
  end

  def solution_folder_params_with_company_visibility
    params = solution_folder_api_params
    params["solution_folder"]["visibility"] = 4
    customer_id = { "customer_folders_attributes" => { "customer_id" => "#{@new_company.id}" } }
    params["solution_folder"].merge!(customer_id)
    params
  end
end
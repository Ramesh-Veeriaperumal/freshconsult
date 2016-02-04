require 'spec_helper'

RSpec.describe Solution::FoldersController do

  self.use_transactional_fixtures = false


  before(:all) do
    @user = create_dummy_customer
    @solution_category = create_category
    @new_company = FactoryGirl.build(:company, :name => Faker::Name.name)
    @new_company.save
    @new_company.reload
  end


  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should be able to create a solution folder" do
    params = solution_folder_api_params
    post :create, params.merge!(:category_id=>@solution_category.id,:format => 'xml'), :content_type => 'application/xml'
    result = parse_xml(response)
    expect(response.status).to be_eql(201)
    expect(assert_array(result["solution_folder"].keys, APIHelper::SOLUTION_FOLDER_ATTRIBS)).to be_empty
  end

  it "should be able to update a solution folder" do
    @test_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @solution_category.id } ) 
    put :update, { :id => @test_folder.id, :category_id=>@solution_category.id, :solution_folder => {:description => Faker::Lorem.paragraph }, :format => 'xml'}
    expect(response.status).to be_eql(200)
  end

  it "should be able to view a solution folder" do
    @test_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @solution_category.id } )
    @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @test_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    get :show, { :category_id => @solution_category.id, :id=>@test_folder.id, :format => 'xml'}
    result = parse_xml(response)
    expect(response.status).to be_eql(200)
    expect(assert_array(result["solution_folder"].keys, APIHelper::SOLUTION_FOLDER_ATTRIBS, ["articles"])).to be_empty
    expect(assert_array(result["solution_folder"]["articles"].first.keys, APIHelper::SOLUTION_ARTICLE_ATTRIBS, ["tags", "folder"])).to be_empty
  end

  it "should be able to delete a solution folder" do
    @test_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @solution_category.id } )
    delete :destroy, { :category_id => @solution_category.id, :id=>@test_folder.id, :format => 'xml'}
    expect(response.status).to be_eql(200)
  end

  it "should be able to create a solution folder with visibility being selected companies" do
    params = solution_folder_params_with_company_visibility
    post :create, params.merge!(:category_id=>@solution_category.id,:format => 'xml'), :content_type => 'application/xml'
    result = parse_xml(response)
    expect(response.status).to be_eql(201)
    expect(assert_array(result["solution_folder"].keys, APIHelper::SOLUTION_FOLDER_ATTRIBS)).to be_empty
    customer_id = @account.folders.find_by_name(params["solution_folder"]["name"] ).solution_folder_meta.customer_folders.first.customer.id
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
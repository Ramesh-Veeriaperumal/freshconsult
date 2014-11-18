require 'spec_helper'

RSpec.describe Solution::FoldersController do

  self.use_transactional_fixtures = false


  before(:all) do
    @user = create_dummy_customer
    @solution_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
  end


  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

 it "should be able to create a solution folder" do
    params = solution_folder_api_params
    post :create, params.merge!(:category_id=>@solution_category.id,:format => 'xml'), :content_type => 'application/xml'
    result = parse_xml(response)
    expected = (response.status === 201) && (compare(result["solution_folder"].keys,APIHelper::SOLUTION_FOLDER_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  it "should be able to update a solution folder" do
    @test_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @solution_category.id } ) 
    put :update, { :id => @test_folder.id, :category_id=>@solution_category.id, :solution_folder => {:description => Faker::Lorem.paragraph }, :format => 'xml'}
    response.status.should === 200
  end
  it "should be able to view a solution folder" do
    @test_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @solution_category.id } )
    get :show, { :category_id => @solution_category.id, :id=>@test_folder.id, :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status === 200) &&  (compare(result["solution_folder"].keys-["articles"],APIHelper::SOLUTION_FOLDER_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  it "should be able to delete a solution folder" do
    @test_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
     :category_id => @solution_category.id } )
    delete :destroy, { :category_id => @solution_category.id, :id=>@test_folder.id, :format => 'xml'}
    response.status.should === 200
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
end
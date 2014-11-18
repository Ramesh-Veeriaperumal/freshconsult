require 'spec_helper'

RSpec.describe Solution::ArticlesController do

  self.use_transactional_fixtures = false


  before(:all) do
    @user = create_dummy_customer
    @solution_category = create_category( {:name => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :is_default => false} )
    @solution_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :visibility => 1,:category_id => @solution_category.id } )
  end


  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should be able to create a solution article" do
    params = article_api_params
    post :create, params.merge!(:category_id=>@solution_category.id,:folder_id=>@solution_folder.id, 
      :tags => {:name => "new"},:format => 'xml'), :content_type => 'application/xml'
    result = parse_xml(response)
    expected = (response.status === 201) && (compare(result["solution_article"].keys,APIHelper::SOLUTION_ARTICLE_ATTRIBS-[ "tags", "folder"],{}).empty?)
    expected.should be(true)
  end
  it "should be able to update a solution article" do
    params = article_api_params
    @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @solution_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    put :update, params.merge!(:category_id=>@solution_category.id,:folder_id=>@solution_folder.id,:id=>@test_article.id,
      :tags => {:name => "new"}, :format => 'xml'), :content_type => 'application/xml'
    result = parse_xml(response)
    puts compare(result["solution_article"].keys,APIHelper::SOLUTION_ARTICLE_ATTRIBS,{})
    expected = (response.status === 201) && (compare(result["solution_article"].keys,APIHelper::SOLUTION_ARTICLE_ATTRIBS-[ "tags", "folder"],{}).empty?)
    expected.should be(true)
  end
it "should be able to view a solution article" do
    @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @solution_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    get :show, { :category_id=>@solution_category.id,:folder_id=>@solution_folder.id,:id => @test_article.id, :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status === 200)  &&  (compare(result["solution_article"].keys,APIHelper::SOLUTION_ARTICLE_ATTRIBS-[ "tags", "folder"],{}).empty?)
    expected.should be(true)
  end
  it "should be able to delete a solution article" do
    @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @solution_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    delete :destroy, { :id => @test_article.id, :format => 'xml'}
    expected = (response.status === 200)
    expected.should be(true)
  end
  #negative checks
  it "should not be able to create a solution article without title" do
    params = {"solution_article"=> { "description"=>Faker::Lorem.sentence(3), "folder_id"=>1}}
    post :create, params.merge!(:category_id=>@solution_category.id,:folder_id=>@solution_folder.id, 
      :tags => {:name => "new"},:format => 'xml'), :content_type => 'application/xml'
    response.status.should === 422
  end

  def article_api_params
    {
      "solution_article"=>
        {
          "title"=>Faker::Lorem.sentence(2),
          "status"=>1, 
          "art_type"=>2, 
          "description"=>Faker::Lorem.sentence(3), 
          "folder_id"=>1
        }
    }
  end

end
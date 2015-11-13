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
      :tags => {:name => "new"},:format => 'json'), :content_type => 'application/json'
    result = parse_json(response)
    expected = (response.status === 201) && (compare(result["article"].keys,APIHelper::SOLUTION_ARTICLE_ATTRIBS,{}).empty?)
    expected.should be(true)
    result["article"]["status"].should be_eql(2)
  end

  it "should be able to create a solution article with default status and art_type values, when status is not passed in params" do
    params =     {
      "solution_article"=>
        {
          "title"=>Faker::Lorem.sentence(2), 
          "description"=>Faker::Lorem.sentence(3), 
          "folder_id"=> @solution_folder.id
        }
    }
    post :create, params.merge!(:category_id=>@solution_category.id,:folder_id=>@solution_folder.id, 
      :tags => {:name => "new"},:format => 'json'), :content_type => 'application/json'
    result = parse_json(response)
    result["article"]["status"].should be_eql(2)
    result["article"]["art_type"].should be_eql(1)
  end

  it "should be able to update a solution article" do
    params = article_api_params
    @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @solution_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    put :update, params.merge!(:category_id=>@solution_category.id,:folder_id=>@solution_folder.id,:id=>@test_article.id,
      :tags => {:name => "new"}, :format => 'json'), :content_type => 'application/json'
    result = parse_json(response)
    expected = (response.status === 200) && (compare(result["article"].keys,APIHelper::SOLUTION_ARTICLE_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  it "should be able to view a solution article" do
    @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @solution_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    get :show, { :category_id=>@solution_category.id,:folder_id=>@solution_folder.id,:id => @test_article.id, :format => 'json'}
    result = parse_json(response)
    expected = (response.status === 200)  &&  (compare(result["article"].keys,APIHelper::SOLUTION_ARTICLE_ATTRIBS,{}).empty?)
    expected.should be(true)
  end
  it "should be able to delete a solution article" do
    @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @solution_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    delete :destroy, { :id => @test_article.id, :format => 'json'}
    expected = (response.status === 200)
    expected.should be(true)
  end
  #negative checks
  it "should not be able to create a solution article without title" do
    params = {"solution_article"=> { "description"=>Faker::Lorem.sentence(3), "folder_id"=>1}}
    post :create, params.merge!(:category_id=>@solution_category.id,:folder_id=>@solution_folder.id, 
      :tags => {:name => "new"},:format => 'json'), :content_type => 'application/json'
    response.status.should === 406
  end
  
  it "should reset thumbs_up and thumbs_down & destroy the votes for that article when reset ratings is done xml" do
    @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @solution_folder.id,
      :user_id => @agent.id, :status => "2", :art_type => "1" } )
    @test_article.reload
    @user_1 = create_dummy_customer
    @test_article.thumbs_up = rand(5..10)
    @test_article.thumbs_down = rand(5..10)
    @test_article.votes.build(:vote => 1, :user_id => @user.id)
    @test_article.votes.build(:vote => 0, :user_id => @user_1.id)
    @test_article.save
    put :reset_ratings, :id => @test_article.id, :category_id => @solution_category.id, :folder_id => @solution_folder.id, :format => 'json'
    @test_article.reload
    expected = (response.status === 200 && @test_article.thumbs_up === 0 && @test_article.thumbs_down === 0 && @test_article.votes === [])
    expected.should be(true)
  end
  

  def article_api_params
    {
      "solution_article"=>
        {
          "title"=>Faker::Lorem.sentence(2),
          "status"=> "2", 
          "art_type"=>2, 
          "description"=>Faker::Lorem.sentence(3), 
          "folder_id"=> @solution_folder.id
        }
    }
  end

end
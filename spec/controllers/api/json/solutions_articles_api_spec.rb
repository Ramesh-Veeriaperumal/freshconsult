require 'spec_helper'

RSpec.describe Solution::ArticlesController do

  self.use_transactional_fixtures = false


  before(:all) do
    @user = create_dummy_customer
    @solution_category_meta = create_category
    @solution_folder_meta = create_folder({ :visibility => 1,:category_id => @solution_category_meta.id })
  end


  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should be able to create a solution article" do
    params = article_api_params
    post :create, params.merge!(:category_id=>@solution_category_meta.id,:folder_id=>@solution_folder_meta.id, 
      :tags => {:name => "new"},:format => 'json'), :content_type => 'application/json'
    result = parse_json(response)

    expect(response.status).to be_eql(201)
    expect(assert_array(result["article"].keys, APIHelper::SOLUTION_ARTICLE_ATTRIBS)).to be_truthy
    expect(result["article"]["status"]).to be_eql(2)
  end

  it "should be able to create a solution article with default status and art_type values, when status is not passed in params" do
    params =     {
      "solution_article"=>
        {
          "title"=>Faker::Lorem.sentence(2), 
          "description"=>Faker::Lorem.sentence(3), 
          "folder_id"=> @solution_folder_meta.id
        }
    }
    post :create, params.merge!(:category_id=>@solution_category_meta.id,:folder_id=>@solution_folder_meta.id, 
      :tags => {:name => "new"},:format => 'json'), :content_type => 'application/json'
    result = parse_json(response)
    expect(result["article"]["status"]).to be_eql(2)
    expect(result["article"]["art_type"]).to be_eql(1)
  end

  it "should be able to update a solution article" do
    params = article_api_params
    @test_article_meta = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @solution_folder_meta.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    put :update, params.merge!(:category_id=>@solution_category_meta.id,:folder_id=>@solution_folder_meta.id,:id=>@test_article_meta.id,
      :tags => {:name => "new"}, :format => 'json'), :content_type => 'application/json'
    result = parse_json(response)

    expect(response.status).to be_eql(200)
    expect(assert_array(result["article"].keys, APIHelper::SOLUTION_ARTICLE_ATTRIBS)).to be_truthy
    expect(result["article"]["status"]).to be_eql(2)
  end

  it "should be able to view a solution article" do
    @test_article_meta = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @solution_folder_meta.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    get :show, { :category_id=>@solution_category_meta.id,:folder_id=>@solution_folder_meta.id,:id => @test_article_meta.id, :format => 'json'}
    result = parse_json(response)
    expect(response.status).to be_eql(200)
    expect(assert_array(result["article"].keys,APIHelper::SOLUTION_ARTICLE_ATTRIBS)).to be_truthy
  end

  it "should be able to delete a solution article" do
    @test_article_meta = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @solution_folder_meta.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    delete :destroy, { :id => @test_article_meta.id, :format => 'json'}
    expect(response.status).to be_truthy
  end

  #negative checks
  it "should not be able to create a solution article without title" do
    params = {"solution_article"=> { "description"=>Faker::Lorem.sentence(3), "folder_id"=>1}}
    post :create, params.merge!(:category_id=>@solution_category_meta.id,:folder_id=>@solution_folder_meta.id, 
      :tags => {:name => "new"},:format => 'json'), :content_type => 'application/json'
    expect(response.status).to be_eql(422)
  end
  
  it "should reset thumbs_up and thumbs_down & destroy the votes for that article when reset ratings is done xml" do
    @test_article_meta = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @solution_folder_meta.id,
      :user_id => @agent.id, :status => "2", :art_type => "1" } )
    @test_article = @test_article_meta.primary_article
    @user_1 = create_dummy_customer
    @test_article.thumbs_up = rand(5..10)
    @test_article.thumbs_down = rand(5..10)
    @test_article.votes.build(:vote => 1, :user_id => @user.id)
    @test_article.votes.build(:vote => 0, :user_id => @user_1.id)
    @test_article.save
    put :reset_ratings, :id => @test_article_meta.id, :category_id => @solution_category_meta.id, :folder_id => @solution_folder_meta.id, :format => 'json'
    @test_article.reload
    expect(response.status).to be_eql(200)
    expect(@test_article.thumbs_up).to be_eql(0)
    expect(@test_article.thumbs_down).to be_eql(0)
    expect(@test_article.votes).to be_eql([])
  end

  def article_api_params
    {
      "solution_article"=>
        {
          "title"=>Faker::Lorem.sentence(2),
          "status"=> "2", 
          "art_type"=>2, 
          "description"=>Faker::Lorem.sentence(3), 
          "folder_id"=> @solution_folder_meta.id
        }
    }
  end

end
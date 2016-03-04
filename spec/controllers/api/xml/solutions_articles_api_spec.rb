require 'spec_helper'

RSpec.describe Solution::ArticlesController do

  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
    @solution_category = create_category
    @solution_folder = create_folder({:visibility => 1,:category_id => @solution_category.id})
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
    expect(response.status).to be_eql(200)
    expect(assert_array(result["solution_article"].keys, APIHelper::SOLUTION_ARTICLE_ATTRIBS, [ "tags", "folder"])).to be_empty
    expect(result["solution_article"]["status"]).to be_eql(2)
  end

  it "should be able to update a solution article" do
    params = article_api_params
    @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @solution_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    put :update, params.merge!(:category_id=>@solution_category.id,:folder_id=>@solution_folder.id,:id=>@test_article.id,
      :tags => {:name => "new"}, :format => 'xml'), :content_type => 'application/xml'
    result = parse_xml(response)
    expect(response.status).to be_eql(200)
    expect(assert_array(result["solution_article"].keys, APIHelper::SOLUTION_ARTICLE_ATTRIBS, ["tags", "folder"])).to be_empty
  end

  it "should be able to view a solution article" do
    @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @solution_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    get :show, { :category_id=>@solution_category.id,:folder_id=>@solution_folder.id,:id => @test_article.id, :format => 'xml'}
    result = parse_xml(response)
    expect(response.status).to be_eql(200)
    expect(assert_array(result["solution_article"].keys, APIHelper::SOLUTION_ARTICLE_ATTRIBS, [ "tags", "folder"])).to be_empty
  end

  it "should be able to delete a solution article" do
    @test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @solution_folder.id, :user_id => @agent.id, :status => "2", :art_type => "1" } )
    delete :destroy, { :id => @test_article.id, :format => 'xml'}
    expect(response.status).to be_eql(200)
  end

  #negative checks
  it "should not be able to create a solution article without title" do
    params = {"solution_article"=> { "description"=>Faker::Lorem.sentence(3), "folder_id"=>1}}
    post :create, params.merge!(:category_id=>@solution_category.id,:folder_id=>@solution_folder.id, 
      :tags => {:name => "new"},:format => 'xml'), :content_type => 'application/xml'
    expect(response.status).to be_eql(422)
  end
  
  it "should reset thumbs_up and thumbs_down & destroy the votes for that article when reset ratings is done xml" do
    @test_article_meta = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @solution_folder.id,
      :user_id => @agent.id, :status => "2", :art_type => "1" } )
    @test_article = @test_article_meta.primary_article
    @test_article.reload
    @user_1 = create_dummy_customer
    @test_article.thumbs_up = rand(5..10)
    @test_article.thumbs_down = rand(5..10)
    @test_article.votes.build(:vote => 1, :user_id => @user.id)
    @test_article.votes.build(:vote => 0, :user_id => @user_1.id)
    @test_article.save
    put :reset_ratings, :id => @test_article.id, :category_id => @solution_category.id, :folder_id => @solution_folder.id, :format => 'xml'
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
          "status"=>"2", 
          "art_type"=>2, 
          "description"=>Faker::Lorem.sentence(3), 
          "folder_id"=> @solution_folder.id
        }
    }
  end

end
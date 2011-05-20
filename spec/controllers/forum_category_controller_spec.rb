require 'spec/spec_helper'

describe ForumCategoriesController do
  
  before do
      @forum_category = mock_model(ForumCategory)
      ForumCategory.stub(:find_by_id).with("1").and_return(@forum_category)
      #ForumCategory.should_receive(:find_by_id).with("1").and_return(@forum_category)
      #ForumCategory.find_by_id("1")
  end
  
  it "should use ForumCategorysController" do
    controller.should be_an_instance_of(ForumCategoriesController)
    controller.stub!(:logger).and_return(Logger.new(STDOUT))
  end
  
  describe "GET 'index'" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end
  end
  
  describe "GET 'show'" do
    it "should be successful" do
      get 'show', :id => @forum_category
      response.should be_success
    end
  end
  
  describe "GET 'new'" do
    it "should be successful" do
      get 'new'
      response.should be_success
    end
  end
  
  describe "GET 'edit'" do
    it "should be successful" do
      get 'edit'
      response.should be_success
    end
  end
  
  describe "GET 'create'" do
    it "should be successful" do
      get 'create'
      response.should be_success
    end
  end
  
  describe "GET 'update'" do
    it "should be successful" do
      get 'update'
      response.should be_success
    end
  end
  
  describe "GET 'destroy'" do
    it "should be successful" do
      get 'destroy', :id => @forum_category
      response.should be_success
    end
  end
  
  it "should create forum_category" do
    post :create, :forumcategory => {:name => "Test"}
    response.should redirect_to(categories_url)
  end
 
  
  
  
end

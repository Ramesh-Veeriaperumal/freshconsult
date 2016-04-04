require 'spec_helper'

describe Mobihelp::ArticlesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user_attributes =  {:name => "mh_article_user", :email => "article_user@mobihelp.in"}
    @test_category =    create_category({:name => "mobihelp category", :description => "mobihelp category",
                          :is_default => false})
    @test_folder =      create_folder({:name => "mobihelp folder", :description => "mobihelp folder",
                           :visibility => 1, :category_id => @test_category.id })
    @test_article =     create_article({:title => "mobihelp article", :description => "mobihelp article", 
                          :folder_id => @test_folder.id, :user_id => @agent.id, :status => "2",
                          :art_type => "1" })
    @mobihelp_app =     create_mobihelp_app
    @mobihelp_auth =    get_app_auth_key(@mobihelp_app) 
  end

  before(:each) do
    @request.env['X-FD-Mobihelp-Auth'] = @mobihelp_auth 
    @request.env["HTTP_ACCEPT"] = "application/json"
  end

  describe "Anonymous user" do
    it "should vote up" do
      put  :thumbs_up, :id => @test_article.id

      result = JSON.parse(response.body)
      result["success"].should be true
    end

    it "should vote down" do 
      put :thumbs_down, :id => @test_article.id
      result = JSON.parse(response.body)
      result["success"].should be true
    end
  end

  describe "Registered user" do
    before(:all) do
      @register_user = add_new_user(@account, @user_attributes)
    end

    before(:each) do
      @request.env['Authorization'] = "Basic "+Base64.encode64(@register_user.single_access_token)
    end

    it "should vote up" do
      put  :thumbs_up, :id => @test_article.id

      result = JSON.parse(response.body)
      result["success"].should be true
    end

    
    it "should vote down" do 
      put :thumbs_down, :id => @test_article.id
      
      result = JSON.parse(response.body)
      result["success"].should be true
    end
  end

  describe "Agent" do
    before(:all) do
      role_ids = [@account.roles.find_by_name("Agent").id.to_s]
      @agent = add_agent(@account, @user_attributes.merge(:email => "agent@mobihelp.in",
                                                          :helpdesk_agent => true, :active => 1, 
                                                          :role => 1, :agent => 1,
                                                          :role_ids => role_ids))
    end

    before(:each) do
      @request.env['Authorization'] = "Basic "+Base64.encode64(@agent.single_access_token)
    end

    it "should vote up" do
      put  :thumbs_up, :id => @test_article.id

      result = JSON.parse(response.body)
      result["success"].should be true
    end

    
    it "should vote down" do 
      put :thumbs_down, :id => @test_article.id

      result = JSON.parse(response.body)
      result["success"].should be true
    end
  end

  describe "Deleted user" do
    before(:all) do
      @deleted_user = add_new_user(@account, @user_attributes.merge(:email => "deleted_user@mobihelp.in",
                                                                    :deleted => true))
    end

    before(:each) do
      @request.env['Authorization'] = "Basic "+Base64.encode64(@deleted_user.single_access_token)
    end

    it "should vote up" do
      put  :thumbs_up, :id => @test_article.id

      result = JSON.parse(response.body)
      result["success"].should be true
    end

    
    it "should vote down" do 
      put :thumbs_down, :id => @test_article.id

      result = JSON.parse(response.body)
      result["success"].should be true
    end
  end

  describe "Blocked user" do
    before(:all) do
      @blocked_user = add_new_user(@account, @user_attributes.merge(:email => "blocked_user@mobihelp.in",
                                                                    :blocked => true))
    end

    before(:each) do
      @request.env['Authorization'] = "Basic "+Base64.encode64(@blocked_user.single_access_token)
    end

    it "should vote up" do
      put  :thumbs_up, :id => @test_article.id

      result = JSON.parse(response.body)
      result["success"].should be true
    end

    
    it "should vote down" do 
      put :thumbs_down, :id => @test_article.id
      result = JSON.parse(response.body)
      result["success"].should be true
    end
  end
end

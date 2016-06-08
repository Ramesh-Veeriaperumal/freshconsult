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
  
  describe "it should vote up/down only primary article" do
    before(:all) do
      @account.account_additional_settings.update_attributes({:supported_languages => pick_languages(@account.language, 3)})
      @account.reload
      @lang_ver = @account.supported_languages_objects.first
      @test_category.send("build_#{@lang_ver.to_key}_category",{:name => "Mobihelp articles category in #{@lang_ver.code}" } )
      @test_category.save
      @test_folder.send("build_#{@lang_ver.to_key}_folder",
                {:name => "Mobihelp articles folder in #{@lang_ver.code}" } )
      @test_folder.save
      agent = add_test_agent(@account)
      agent.make_current
      @article_version = @test_article.send("build_#{@lang_ver.to_key}_article",
            {:title => "Mobihelp #{@lang_ver.to_key} title", :description => "Mobihelp #{@lang_ver.to_key} description",
            :status => 2, :user_id => agent.id})
      @article_version.save
      User.reset_current_user
    end
    
    before(:each) do
      @test_article.reload
      @old_parent = @test_article.dup
      @old_primary = @test_article.primary_article.dup
      @old_version = @article_version.dup
    end
    
    after(:each) do
      @test_article.reload
      current_vote_type = controller.action_name
      @test_article.send(current_vote_type).should be_eql(@old_parent.send(current_vote_type) + 1)
      @test_article.primary_article.send(current_vote_type).should be_eql(@old_primary.send(current_vote_type) + 1)
      @old_version.send(current_vote_type).should be_eql(@article_version.send(current_vote_type))
    end
    
    it "should vote up only the primary article and not any other version" do
      put :thumbs_up, :id => @test_article.id
    end
    
    it "should vote down only the primary article and not any other version" do
      put :thumbs_down, :id => @test_article.id
    end
  end
end

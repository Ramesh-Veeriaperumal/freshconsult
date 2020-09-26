require 'spec_helper'

describe 'Language prefix', :type => :request do
	setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.reload
  	RoutingFilter.active = true
  	ActionController::Base.allow_forgery_protection = true
  	@new_agent = add_test_agent(@account,  {:role => @account.roles.first.id})
    @new_agent.password = "test1234"
    @new_agent.save
    @user = create_dummy_customer
    @user.password = "test1234"
    @user.save
    @test_category_meta = create_category
    @public_folder_meta  = create_folder({ :visibility => 1, :category_id => @test_category_meta.id })
    @folder_meta  = create_folder({ :visibility => 1, :category_id => @test_category_meta.id })
		@public_article_meta = create_article({ :folder_id => @public_folder_meta.id, :status => 2, :art_type => 1, :user_id => @agent.id })
    @article_meta = create_article({ :folder_id => @public_folder_meta.id, :status => 2, :art_type => 1, :user_id => @agent.id })
  end

  before(:each) do
  	@account.reload
    @account.make_current
  	enable_multilingual
  end

  describe "support home page" do
    it "should redirect to support home page without language prefix if multilingual is not enabled" do
      destroy_enable_multilingual_feature
      get "http://#{@account.full_domain}/#{@account.language}/support/home"
      response.should redirect_to "http://#{@account.full_domain}/support/home"
    end

    it "should render support home page with url locale as language prefix if multilingual is enabled and url is valid" do
    	url_locale = @account.language
    	get "http://#{@account.full_domain}/#{url_locale}/support/home"
    	I18n.locale.should be_eql(@account.language.to_sym)
    	response.code.should be_eql("200")
    end

    it "should redirect to support home page with current language as language prefix if multilingual is enabled and url is invalid" do
    	url_locale = pick_a_unsupported_language
    	get "http://#{@account.full_domain}/#{url_locale}/support/home"
    	I18n.locale.should be_eql(@account.language.to_sym)
    	response.should redirect_to "http://#{@account.full_domain}/#{@account.language}/support/home"
    end

    it "should render support home page with url locale as language prefix if multilingual is enabled, logged in user is an agent and url locale is a supported language" do
    	post "http://#{@account.full_domain}/#{@account.language}/support/login", :user_session => { :email => @new_agent.email, :password => "test1234", :remember_me => "0" }
    	url_locale = @account.portal_languages.first
    	get "http://#{@account.full_domain}/#{url_locale}/support/home"
    	I18n.locale.should be_eql(url_locale.to_sym)
    	response.code.should be_eql("200")
    end

    it "should override the I18n locale when a user is logged in and the user's language is a supported language" do
      @new_agent.update_attribute(:language, @account.portal_languages.sample)
    	post "http://#{@account.full_domain}/#{@account.language}/support/login", :user_session => { :email => @new_agent.email, :password => "test1234", :remember_me => "0" }
    	url_locale = (@account.portal_languages.reject{ |l| l == @new_agent.reload.language }).sample.dup
    	get "http://#{@account.full_domain}/#{url_locale}/support/home"
    	I18n.locale.should_not be_eql(@new_agent.language.to_sym)
    	I18n.locale.should be_eql(url_locale.to_sym)
    end

    it "should override the I18n locale when a user is not logged in if it is not same as current language" do
      get "http://#{@account.full_domain}/logout"
    	url_locale = (@account.reload.portal_languages.reject{ |l| l == @account.language }).sample.dup
    	get "http://#{@account.full_domain}/#{url_locale}/support/home"
    	I18n.locale.to_s.should be_eql(url_locale)
    end

    it "should not override I18n locale if logged in user's language is not present in portal languages" do
      @user.update_attribute(:language, pick_a_unsupported_language)
      post "http://#{@account.full_domain}/#{@account.language}/support/login", :user_session => { :email => @user.email, :password => "test1234", :remember_me => "0" }
      url_locale = (@account.portal_languages.reject{ |l| l == @user.reload.language }).sample.dup
      get "http://#{@account.full_domain}/#{url_locale}/support/home"
      I18n.locale.should be_eql(@user.language.to_sym)
    end
  end

  describe "support article page" do
    it "should redirect to support article page without language prefix if multilingual is not enabled" do
      destroy_enable_multilingual_feature
      get "http://#{@account.full_domain}/#{@account.language}/support/articles/#{@public_article_meta.id}"
      response.should redirect_to "http://#{@account.full_domain}/support/articles/#{@public_article_meta.id}"
    end

    it "should render support article page with url locale as language prefix if multilingual is enabled and url is valid" do
      url_locale = @account.language
      get "http://#{@account.full_domain}/#{url_locale}/support/articles/#{@public_article_meta.id}"
      @account.make_current
      response.body.should =~ /#{@public_article_meta.primary_article.title}/
      I18n.locale.should be_eql(@account.language.to_sym)
      response.code.should be_eql("200")
    end

    it "should redirect to support article page with current language as language prefix if multilingual is enabled and url is invalid" do
      url_locale = pick_a_unsupported_language
      get "http://#{@account.full_domain}/#{url_locale}/support/articles/#{@public_article_meta.id}"
      I18n.locale.should be_eql(@account.language.to_sym)
      response.should redirect_to "http://#{@account.full_domain}/#{@account.language}/support/articles/#{@public_article_meta.id}"
    end

    it "should redirect to support home page with url locale as language prefix if multilingual is enabled, logged in user is an agent and url locale is a supported language but article in that language is not available" do
      post "http://#{@account.full_domain}/#{@account.language}/support/login", :user_session => { :email => @new_agent.email, :password => "test1234", :remember_me => "0" }
      url_locale = @account.portal_languages.first
      get "http://#{@account.full_domain}/#{url_locale}/support/articles/#{@public_article_meta.id}"
      response.should redirect_to "http://#{@account.full_domain}/#{url_locale}/support/home"
    end

    it "should render solution article page with url locale as language prefix if multilingual is enabled, logged in user is an agent and url locale is a supported language and article in that language is available" do
      @new_agent.update_attribute(:language, @account.portal_languages.sample)
      post "http://#{@account.full_domain}/#{@account.language}/support/login", :user_session => { :email => @new_agent.email, :password => "test1234", :remember_me => "0" }
      @account.make_current
      @agent.make_current
      language_code = @account.portal_languages.first
      @category_version = @test_category_meta.solution_categories.new({ :name => "#{Faker::Lorem.sentence(3)}" })
      @category_version.language_id = Language.find_by_code(language_code).id
      @category_version.save
      @folder_version = @public_folder_meta.solution_folders.new({ :name => "#{Faker::Lorem.sentence(3)}" })
      @folder_version.language_id = Language.find_by_code(language_code).id
      @folder_version.save
      @article_version = @article_meta.solution_articles.new({ :title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :user_id => @new_agent.id, :status => 2 })
      @article_version.language_id = Language.find_by_code(language_code).id
    	@article_version.save
      url_locale = language_code
      get "http://#{@account.full_domain}/#{url_locale}/support/articles/#{@article_meta.id}"
      @account.make_current
      response.body.should =~ /#{@article_version.title}/
      I18n.locale.should be_eql(url_locale.to_sym)
      response.code.should be_eql("200") 
    end

    it "should override the I18n locale when a user is logged in and his language is a supported language" do
      @new_agent.update_attribute(:language, @account.portal_languages.sample)
      post "http://#{@account.full_domain}/#{@account.language}/support/login", :user_session => { :email => @new_agent.email, :password => "test1234", :remember_me => "0" }
      url_locale = (@account.portal_languages.reject{ |l| l == @new_agent.reload.language }).sample.dup
      get "http://#{@account.full_domain}/#{url_locale}/support/articles/#{@public_article_meta.id}"
      I18n.locale.should be_eql(url_locale.to_sym)
      I18n.locale.should_not be_eql(@new_agent.language.to_sym)
    end

    it "should override the I18n locale when a user is not logged in if it is not same as current language" do
      get "http://#{@account.full_domain}/logout"
      url_locale = (@account.portal_languages.reject{ |l| l == I18n.locale }).sample.dup
      get "http://#{@account.full_domain}/#{url_locale}/support/articles/#{@public_article_meta.id}"
      I18n.locale.to_s.should be_eql(url_locale)
    end

    it "should not override I18n locale if logged in user's language is not present in portal languages" do
      @user.update_attribute(:language, pick_a_unsupported_language)
      post "http://#{@account.full_domain}/#{@account.language}/support/login", :user_session => { :email => @user.email, :password => "test1234", :remember_me => "0" }
      url_locale = (@account.portal_languages.reject{ |l| l == @user.reload.language }).sample.dup
      get "http://#{@account.full_domain}/#{url_locale}/support/articles/#{@public_article_meta.id}"
      I18n.locale.should be_eql(@user.language.to_sym)
      I18n.locale.should_not be_eql(url_locale.to_sym)
    end

  end

  describe "support folder page" do
    it "should redirect to support folder page without language prefix if multilingual is not enabled" do
      destroy_enable_multilingual_feature
      get "http://#{@account.full_domain}/#{@account.language}/support/solutions/folders/#{@public_folder_meta.id}"
      response.should redirect_to "http://#{@account.full_domain}/support/solutions/folders/#{@public_folder_meta.id}"
    end

    it "should render support folder page with url locale as language prefix if multilingual is enabled and url is valid" do
      url_locale = @account.language
      get "http://#{@account.full_domain}/#{url_locale}/support/solutions/folders/#{@public_folder_meta.id}"
      I18n.locale.should be_eql(@account.language.to_sym)
      response.code.should be_eql("200")
    end

    it "should redirect to support folder page with current language as language prefix if multilingual is enabled and url is invalid" do
      url_locale = pick_a_unsupported_language
      get "http://#{@account.full_domain}/#{url_locale}/support/solutions/folders/#{@public_folder_meta.id}"
      I18n.locale.should be_eql(@account.language.to_sym)
      response.should redirect_to "http://#{@account.full_domain}/#{@account.language}/support/solutions/folders/#{@public_folder_meta.id}"
    end

    it "should redirect to support home page with url locale as language prefix if multilingual is enabled, logged in user is an agent and url locale is a supported language but the folder is not available in that language" do
      post "http://#{@account.full_domain}/#{@account.language}/support/login", :user_session => { :email => @new_agent.email, :password => "test1234", :remember_me => "0" }
      url_locale = @account.portal_languages.first
      get "http://#{@account.full_domain}/#{url_locale}/support/solutions/folders/#{@folder_meta.id}"
      response.should redirect_to "http://#{@account.full_domain}/#{url_locale}/support/home"
    end

    it "should render solution folder page with url locale as language prefix if multilingual is enabled, logged in user is an agent and url locale is a supported language and folder in that language is available" do
      post "http://#{@account.full_domain}/#{@account.language}/support/login", :user_session => { :email => @new_agent.email, :password => "test1234", :remember_me => "0" }
      @account.make_current
      @agent.make_current
      @category_version = @test_category_meta.solution_categories.new({ :name => "#{Faker::Lorem.sentence(3)}" })
      @category_version.language_id = Language.find_by_code(@account.portal_languages.first).id
      @category_version.save
      @folder_version = @folder_meta.solution_folders.new({ :name => "#{Faker::Lorem.sentence(3)}" })
      @folder_version.language_id = Language.find_by_code(@account.portal_languages.first).id
    	@folder_version.save
      url_locale = @folder_version.language.code
      get "http://#{@account.full_domain}/#{url_locale}/support/solutions/folders/#{@folder_meta.id}"
      response.body.should =~ /#{@folder_version.name}/
      response.code.should be_eql("200") 
    end

    it "should override the I18n locale when a user is logged in and user's language is a supported language" do
      @new_agent.update_attribute(:language, @account.portal_languages.sample)
      post "http://#{@account.full_domain}/#{@account.language}/support/login", :user_session => { :email => @new_agent.email, :password => "test1234", :remember_me => "0" }
      url_locale = (@account.portal_languages.reject{ |l| l == @new_agent.reload.language }).sample.dup
      get "http://#{@account.full_domain}/#{url_locale}/support/solutions/folders/#{@public_folder_meta.id}"
      I18n.locale.should be_eql(url_locale.to_sym)
      I18n.locale.should_not be_eql(@new_agent.language.to_sym)
    end

    it "should override the I18n locale when a user is not logged in if it is not same as current language" do
      get "http://#{@account.full_domain}/logout"
      url_locale = (@account.portal_languages.reject{ |l| l == I18n.locale }).sample.dup
      get "http://#{@account.full_domain}/#{url_locale}/support/solutions/folders/#{@public_folder_meta.id}"
      I18n.locale.to_s.should be_eql(url_locale)
    end

    it "should not override I18n locale if logged in user's language is not present in portal languages" do
      @user.update_attribute(:language, pick_a_unsupported_language)
      post "http://#{@account.full_domain}/#{@account.language}/support/login", :user_session => { :email => @user.email, :password => "test1234", :remember_me => "0" }
      url_locale = (@account.portal_languages.reject{ |l| l == @user.reload.language }).sample.dup
      get "http://#{@account.full_domain}/#{url_locale}/support/solutions/folders/#{@public_folder_meta.id}"
      I18n.locale.should be_eql(@user.language.to_sym)
    end
  end
end

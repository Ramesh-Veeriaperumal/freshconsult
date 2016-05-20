require 'spec_helper'

describe 'Visibility', :type => :request do
	setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
  	RoutingFilter.active = true
  	ActionController::Base.allow_forgery_protection = true
  	@new_agent = add_test_agent(@account,  {:role => @account.roles.first.id})
    @new_agent.password = "test1234"
    @new_agent.save
    Language.reset_current
		enable_multilingual
		@account.account_additional_settings.additional_settings[:portal_languages] = 
				@account.supported_languages[0..-2]
		@account.account_additional_settings.save
		@account.reload
		Language.reset_current
		@lang_ver = @account.portal_languages_objects.last
		@non_portal_lang = (@account.supported_languages_objects - @account.portal_languages_objects).first
		params = create_solution_category_alone(solution_default_params(:category).merge({
              :lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary]
             }))
    @category1 = Solution::Builder.category(params)
			folder_params = create_solution_folder_alone(solution_default_params(:folder).merge({
							:category_id => @category1.id,
				     	:lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary]
				     }))
		@folder1 = Solution::Builder.folder(folder_params)
		@new_agent.make_current
		2.times.each do |i|
			article_params = params = create_solution_article_alone(solution_default_params(:article, :title,
								{:title => "Folder 1 Article #{i+1} #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}"}).merge({
								:folder_id => @folder1.id,
					     	:lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary],
								:status => 2, :user_id => @new_agent.id,
					     }))
			Solution::Builder.article(article_params)
		end
		User.reset_current_user
		params = create_solution_category_alone(solution_default_params(:category, :name, 
							{:name => "Category 2 #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}"}).merge({
              :lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary]
             }))
		@category2 = Solution::Builder.category(params)
		folder_params = create_solution_folder_alone(solution_default_params(:folder, :name, 
		 					{:name => "Folder 2 #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}"}).merge({
							:category_id => @category2.id,
				     	:lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary]
				     }))
		@folder2 = Solution::Builder.folder(folder_params)
		@user = add_new_user(@account)	
		@user.password = "test1234"
		@user.save
	end
  
  before(:each) do 
    @account.make_current
    Language.reset_current
  end
	
	it "should display categories in the language specified that are visible in the current portal" do
		portal = create_portal
		params = create_solution_category_alone(solution_default_params(:category, :name,
							{:name => "invisible_category #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}"}).merge({
              :lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary]
             }))
		params[:solution_category_meta][:portal_ids] = [portal.id]
    @invisible_category = Solution::Builder.category(params)
		folder_params = create_solution_folder_alone(solution_default_params(:folder, :name, 
		 					{:name => "invisible_folder #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}"}).merge({
							:category_id => @invisible_category.id,
				     	:lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary]
				     }))
		@invisible_folder = Solution::Builder.folder(folder_params)
		get "http://#{@account.full_domain}/#{@lang_ver.code}/support/home"
		response.body.should =~ /#{@category1.send("#{@lang_ver.to_key}_category").name}/
		response.body.should =~ /#{@folder1.send("#{@lang_ver.to_key}_folder").name}/
		response.body.should =~ /#{@category2.send("#{@lang_ver.to_key}_category").name}/
		response.body.should =~ /#{@folder2.send("#{@lang_ver.to_key}_folder").name}/
		response.body.should_not =~ /#{@category1.primary_category.name}/
    response.body.should_not =~ /#{@invisible_category.send("#{@lang_ver.to_key}_category").name}/
		response.body.should_not =~ /#{@invisible_folder.send("#{@lang_ver.to_key}_folder").name}/
	end
	
	it "should display folders in the current category in the specified language based on logged in user" do
		folder_params = create_solution_folder_alone(solution_default_params(:folder, :name, 
		 					{:name => "Visible to logged in #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}"}).merge({
							:category_id => @category1.id,
				     	:lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary],
							:visibility => 2
				     }))
		logged_in_folder = Solution::Builder.folder(folder_params)
		article_params = create_solution_article_alone(solution_default_params(:article, :title,
							{:title => "Logged in Folder 1 Article #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}"}).merge({
							:folder_id => logged_in_folder.id,
							:lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary],
							:status => 2, :user_id => @new_agent.id	
						 }))
		@new_agent.make_current
		Solution::Builder.article(article_params)
		User.reset_current_user
		get "http://#{@account.full_domain}/#{@lang_ver.code}/support/solutions/#{@category1.id}"
		response.body.should =~ /#{@category1.send("#{@lang_ver.to_key}_category").name}/
		response.body.should =~ /#{@folder1.send("#{@lang_ver.to_key}_folder").name}/
		response.body.should_not =~ /#{@folder1.primary_folder.name}/
		response.body.should_not =~ /#{logged_in_folder.send("#{@lang_ver.to_key}_folder").name}/
		get "http://#{@account.full_domain}/#{@lang_ver.code}/support/solutions/#{@category1.id}",
			{}, {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(@user.email,"test1234")}
		response.body.should =~ /#{@category1.send("#{@lang_ver.to_key}_category").name}/
		response.body.should =~ /#{@folder1.send("#{@lang_ver.to_key}_folder").name}/
		response.body.should =~ /#{logged_in_folder.send("#{@lang_ver.to_key}_folder").name}/
		response.body.should_not =~ /#{logged_in_folder.primary_folder.name}/
	end
	
	it "should display folders in the current category in the specified language based on logged in agent" do
		folder_params = create_solution_folder_alone(solution_default_params(:folder, :name, 
		 					{:name => "Visible to agent #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}"}).merge({
							:category_id => @category1.id,
				     	:lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary],
							:visibility => 3
				     }))
		agent_folder = Solution::Builder.folder(folder_params)
		article_params = create_solution_article_alone(solution_default_params(:article, :title,
							{:title => "Loggedreque in Folder 1 Article #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}"}).merge({
							:folder_id => agent_folder.id,
							:lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary],
							:status => 2, :user_id => @new_agent.id
						 }))				
		@new_agent.make_current			 
		Solution::Builder.article(article_params)
		User.reset_current_user
		get "http://#{@account.full_domain}/#{@lang_ver.code}/support/solutions/#{@category1.id}"
		response.body.should =~ /#{@category1.send("#{@lang_ver.to_key}_category").name}/
		response.body.should =~ /#{@folder1.send("#{@lang_ver.to_key}_folder").name}/
		response.body.should_not =~ /#{@folder1.primary_folder.name}/
		response.body.should_not =~ /#{agent_folder.send("#{@lang_ver.to_key}_folder").name}/
		get "http://#{@account.full_domain}/#{@lang_ver.code}/support/solutions/#{@category1.id}",
			{}, {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(@new_agent.email,"test1234")}
		response.body.should =~ /#{@category1.send("#{@lang_ver.to_key}_category").name}/
		response.body.should =~ /#{@folder1.send("#{@lang_ver.to_key}_folder").name}/
		response.body.should =~ /#{agent_folder.send("#{@lang_ver.to_key}_folder").name}/
		response.body.should_not =~ /#{agent_folder.primary_folder.name}/
	end
	
	it "should display folders in the current category in the specified language based on logged in user's company" do
		test_company = create_company
		folder_params = create_solution_folder_alone(solution_default_params(:folder, :name, 
		 					{:name => "Visible to agent #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}"}).merge({
							:category_id => @category1.id,
				     	:lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary],
							:visibility => 4
				     }))
		company_folder = Solution::Builder.folder(folder_params)
		company_folder.customer_ids = [test_company.id]
		company_folder.save
		article_params = create_solution_article_alone(solution_default_params(:article, :title,
							{:title => "Logged in Folder 1 Article #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}"}).merge({
							:folder_id => company_folder.id,
							:lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary],
							:status => 2, :user_id => @new_agent.id
						 }))
		@new_agent.make_current				 
		Solution::Builder.article(article_params)
		User.reset_current_user
		get "http://#{@account.full_domain}/#{@lang_ver.code}/support/solutions/#{@category1.id}",
				{}, {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(@user.email,"test1234")}
		response.body.should =~ /#{@category1.send("#{@lang_ver.to_key}_category").name}/
		response.body.should =~ /#{@folder1.send("#{@lang_ver.to_key}_folder").name}/
		response.body.should_not =~ /#{@folder1.primary_folder.name}/
		response.body.should_not =~ /#{company_folder.send("#{@lang_ver.to_key}_folder").name}/
		@user.update_attribute(:customer_id, test_company.id)
		get "http://#{@account.full_domain}/#{@lang_ver.code}/support/solutions/#{@category1.id}",
			{}, {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(@user.email,"test1234")}
		response.body.should =~ /#{@category1.send("#{@lang_ver.to_key}_category").name}/
		response.body.should =~ /#{@folder1.send("#{@lang_ver.to_key}_folder").name}/
		response.body.should =~ /#{company_folder.send("#{@lang_ver.to_key}_folder").name}/
		response.body.should_not =~ /#{company_folder.primary_folder.name}/
	end
	
	it "should display only published articles of the specified language in the folder show page" do
		article_params = params = create_solution_article_alone(solution_default_params(:article, :title,
							{:title => "Folder 1 Article #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}"}).merge({
							:folder_id => @folder1.id,
							:lang_codes => [@lang_ver.to_key, @non_portal_lang.to_key] + [:primary],
							:status => 1, :user_id => @new_agent.id
						 }))
		@new_agent.make_current
		unpublished_article = Solution::Builder.article(article_params)
		User.reset_current_user
		published_article = @folder1.reload.solution_article_meta.published.first
		get "http://#{@account.full_domain}/#{@lang_ver.code}/support/solutions/folders/#{@folder1.id}"
		@account.make_current
		response.body.should =~ /#{@folder1.send("#{@lang_ver.to_key}_folder").name}/
		response.body.should =~ /#{published_article.send("#{@lang_ver.to_key}_article").title}/
		response.body.should_not =~ /#{published_article.primary_article.title}/
		response.body.should_not =~ /#{unpublished_article.send("#{@lang_ver.to_key}_article").title}/
	end
	
	it "should display article's content in the specified language in the article show page" do
		published_article = @folder1.solution_article_meta.published.sample
		get "http://#{@account.full_domain}/#{@lang_ver.code}/support/articles/#{published_article.id}"
		@account.make_current
		response.body.should =~ /#{published_article.send("#{@lang_ver.to_key}_article").title}/
		response.body.should =~ /#{published_article.send("#{@lang_ver.to_key}_article").description}/
		response.body.should_not =~ /#{published_article.primary_article.title}/
	end
end

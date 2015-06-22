require 'spec_helper'

describe Solution::DraftsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  describe "Solution Drafts" do

	  before(:all) do
	  	@agent1 = add_test_agent
	  	@agent2 = add_test_agent
	  	@test_category = create_category( {:name => "test category #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
	  	@public_folder  = create_folder({
	                                      :name => "Public #{Faker::Name.name} visible to All", 
	                                      :description => "#{Faker::Lorem.sentence(3)}", 
	                                      :visibility => 1,
	                                      :category_id => @test_category.id 
	                                    })

	    @draft_article1 = create_article( {:title => "article1 agent1 #{@agent1.id} #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(1)}", :folder_id => @public_folder.id, 
	      :status => "1", :art_type => "1", :user_id => "#{@agent1.id}" } )

	    @draft_article2 = create_article( {:title => "article2 agent2 #{@agent2.id} #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @public_folder.id, 
	      :status => "1", :art_type => "1", :user_id => "#{@agent2.id}" } )
	  end

	  #start : specs for index action
	  describe "index action" do

	  	before(:each) do
	  		log_in(@agent1)
	  	end

		  it "should render current author drafts listing if index is hit" do
		    get :index
		    response.body.should =~ /#{@draft_article1.title.truncate(35)}/
		  end

		  it "should render only the current author's drafts only" do
		    get :index
		    articles = assigns(:articles)
		    articles.count.should be_eql(1)
		  end

		  it "should render all drafts when visited all drafts path" do
		    get :index, :type => :all
		    articles = assigns(:articles)
		    articles.count.should be_eql(2)
		  end
		end
		#end : specs for index action

		#start : specs for publish action
		describe "publish action" do

			before(:each) do
				log_in(@agent1)

				@draft_article3 = create_article( {:title => "article3 agent1[#{@agent1.id}] #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(2)}", :folder_id => @public_folder.id, 
	      		:status => "1", :art_type => "1", :user_id => "#{@agent1.id}" } )
	  		@draft_article3.create_draft_from_article({:title => "Draft 1 for publish #{Faker::Name.name}", :description => "Desc 1 : #{Faker::Lorem.sentence(4)}"})

	  		request.env["HTTP_REFERER"] = "where_i_came_from"
	  	end

	  	it "should publish an unpublished article without draft record" do
	  		post :publish, :id => @draft_article1.id
	  		@draft_article1.reload
	  		@draft_article1.status.should be_eql(Solution::Article::STATUS_KEYS_BY_TOKEN[:published])
	  	end

	  	it "should publish an unpublished article with a draft record" do
	  		@draft_article3.draft.should_not be_blank
	  		post :publish, :id => @draft_article3.id
	  		response.should redirect_to "where_i_came_from"
	  		@draft_article3.reload
	  		@draft_article3.status.should be_eql(Solution::Article::STATUS_KEYS_BY_TOKEN[:published])
	  		@draft_article3.draft.should_not be_present
	  	end

	  	it "should not publish an unpublished article with draft record if it's locked" do
	  		draft = @draft_article3.draft
	  		draft.user_id = @agent2.id
	  		draft.status = Solution::Draft::STATUS_KEYS_BY_TOKEN[:editing]
	  		draft.save

	  		#draft should be locked
	  		draft.locked?.should be_eql(true)
	  		#article should not be published
	  		@draft_article3.status.should_not be_eql(Solution::Article::STATUS_KEYS_BY_TOKEN[:published])

	  		post :publish, :id => @draft_article3.id
	  		#should redirect to where you came from
	  		response.should redirect_to "where_i_came_from"

	  		@draft_article3.reload
	  		#the draft of the article should exist
	  		@draft_article3.draft.should_not be_blank
	  		#the article should remain unpublished
	  		@draft_article3.status.should_not be_eql(Solution::Article::STATUS_KEYS_BY_TOKEN[:published])
	  	end
		end
		#end : specs for publish action

		#start : specs for destroy action
		describe "destroy action" do

			before(:each) do
				log_in(@agent1)

	    	@draft_article3 = create_article( {:title => "article 3 destroy agent1[#{@agent1.id}] #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(2)}", :folder_id => @public_folder.id, 
	      		:status => "1", :art_type => "1", :user_id => "#{@agent1.id}" } )
	  		@draft_article3.create_draft_from_article({:title => "Draft 1 for destroy #{Faker::Name.name}", :description => "Desc 4 : #{Faker::Lorem.sentence(4)}"})

	  		request.env["HTTP_REFERER"] = "where_i_came_from"
	  	end

	  	it "should not have have flash message if there is not draft for an associated unpublished article" do
	  		delete :destroy, :id => 255, :article_id => @draft_article1.id
	  		response.should redirect_to "where_i_came_from"
	  		flash[:notice].should be_nil
	  	end

	  	it "should delete a draft record" do
	  		@draft_article3.draft.should be_present
	  		delete :destroy, :id => @draft_article3.draft.id, :article_id => @draft_article3.id
	  		#should redirect to where i came from
	  		response.should redirect_to "where_i_came_from"
	  		#the succesfully discarded flash msg should be present
	  		expect(flash[:notice]).to be_present
	  		@draft_article3.reload
	  		#the draft should not be present
	  		@draft_article3.draft.should_not be_present
	  	end

	  	it "should not delete a draft record if it's locked" do
	  		draft = @draft_article3.draft
	  		draft.user_id = @agent2.id
	  		draft.status = Solution::Draft::STATUS_KEYS_BY_TOKEN[:editing]
	  		draft.save
	  		#draft should be locked
	  		draft.locked?.should be_eql(true)

	  		delete :destroy, :id => @draft_article3.draft.id, :article_id => @draft_article3.id
	  		#should redirect to where you came from
	  		response.should redirect_to "where_i_came_from"
	  		#there should not be any flash message
	  		flash[:notice].should be_nil

	  		@draft_article3.reload
	  		#the draft of the article should exist
	  		@draft_article3.draft.should_not be_blank
	  	end


	  	it "should send a notification mail if draft is discard by somebody other than the author" do
	  		draft = @draft_article3.draft
	  		draft.user_id = @agent2.id
	  		draft.status = Solution::Draft::STATUS_KEYS_BY_TOKEN[:work_in_progress]
	  		draft.save

	  		#draft should not be of the agent who discards draft
	  		draft.user_id.should_not be_eql(@agent1.id)

	  		delete :destroy, :id => @draft_article3.draft.id, :article_id => @draft_article3.id

	  		#should redirect to where i came from
	  		response.should redirect_to "where_i_came_from"
	  		#the succesfully discarded flash msg should be present
	  		expect(flash[:notice]).to be_present
	  		@draft_article3.reload
	  		#the draft should not be present
	  		@draft_article3.draft.should_not be_present

	      Delayed::Job.last.handler.should include('DraftMailer')
	      Delayed::Job.last.handler.should include('discard_notification')
	  	end

		end
		#end : specs for destroy action

		#start : specs for attachment delete action
		describe "attachment delete action" do
			
			before(:each) do
				log_in(@agent1)
				@draft_article3 = create_article( {:title => "Article 3 attachment delete agent1[#{@agent1.id}] #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(2)}", :folder_id => @public_folder.id, 
	      		:status => "1", :art_type => "1", :user_id => "#{@agent1.id}" } )
	  		@draft_article3.create_draft_from_article({:title => "Draft 3 for attachment delete #{Faker::Name.name}", :description => "Desc 4 : #{Faker::Lorem.sentence(4)}"})
				@attachment = @draft_article3.attachments.build(:content => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary), 
                                            :description => Faker::Name.first_name, 
                                            :account_id => @draft_article3.account_id)
				@attachment.save
	  		request.env["HTTP_REFERER"] = "where_i_came_from"
	  	end

	  	it "should soft delete the attachment from article draft" do
	  		draft = @draft_article3.draft
	  		draft.should_not be_blank
	  		@draft_article3.attachments.should be_present

	  		delete :attachments_delete, :article_id => @draft_article3.id, :attachment_type => :attachment, :attachment_id => @attachment.id

	  		draft.reload
	  		@draft_article3.reload
	  		@draft_article3.attachments.should be_present
	  		draft.deleted_attachments(:attachments).should be_eql([@attachment.id])
	  	end

		end
		#end : specs for  attachment delete action

		#start : specs for autosave action
		describe "autosave action" do
			
			before(:each) do
				log_in(@agent1)
				@draft_article3 = create_article( {:title => "Article 3 attachment delete agent1[#{@agent1.id}] #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(2)}", :folder_id => @public_folder.id, 
	      		:status => "1", :art_type => "1", :user_id => "#{@agent1.id}" } )
	  		@draft_article3.create_draft_from_article({:title => "Draft 3 for attachment delete #{Faker::Name.name}", :description => "Desc 4 : #{Faker::Lorem.sentence(4)}"})
	  		@draft = @draft_article3.draft
	  	end

	  	#Success case 1. Normal autosave happens
	  	it "should successfully autosave a draft content" do
	  		xhr :post, :autosave, :id => @draft_article3.id, :title => "New", :description => "New Desc", :timestamp => @draft.updation_timestamp
	  		response.code.should be_eql("200")
	  		response.body.should =~ /Draft saved/
	  	end

	  	#Failure case 2. You are editing it from somewhere also
	  	it "should fail: Reason - You are editing it from somewhere" do
	  		xhr :post, :autosave, :id => @draft_article3.id, :title => "New", :description => "New Desc", :timestamp => (@draft.updation_timestamp+23)

	  		response.code.should be_eql("200")
	  		response.body.should =~ /You have updated the content elsewhere/
	  	end

	  	#Failure case 3. Somebody else is editing the article
	  	it "should fail: Reason - Somebody else is editing the article" do
	  		@draft.user_id = @agent2.id
	  		@draft.status = Solution::Draft::STATUS_KEYS_BY_TOKEN[:editing]
	  		@draft.save

	  		xhr :post, :autosave, :id => @draft_article3.id, :title => "New", :description => "New Desc", :timestamp => @draft.updation_timestamp

	  		response.code.should be_eql("200")
	  		response.body.should =~ /#{@agent2.name} is currently editing/
	  	end

	  	#Failure case 4. Content has been updated by someone
	  	it "should fail: Reason - Content has been updated by someone" do
	  		@draft.user_id = @agent2.id
	  		@draft.save
				xhr :post, :autosave, :id => @draft_article3.id, :title => "New", :description => "New Desc", :timestamp => @draft.updation_timestamp + 1
	  		response.code.should be_eql("200")
	  		response.body.should =~ /#{@agent2.name} has updated the content while you were away/
	  	end

	  end
		#end : specs for autosave action

		#Start : specs for Views testing
		describe "checking views" do
			
			before(:each) do
				log_in(@agent1)
				@draft_article3 = create_article( {:title => "Article 3 attachment delete agent1[#{@agent1.id}] #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(2)}", :folder_id => @public_folder.id, 
	      		:status => "1", :art_type => "1", :user_id => "#{@agent1.id}" } )
	  		@draft_article3.create_draft_from_article({:title => "Draft 3 for view testing #{Faker::Name.name}", :description => "Desc 4 : #{Faker::Lorem.sentence(4)}"})
	  		@draft = @draft_article3.draft
	  		@draft_article4 = create_article( {:title => "article4 agent2 #{@agent2.id} #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @public_folder.id, 
	      :status => "1", :art_type => "1", :user_id => "#{@agent2.id}" } )
	  	end

	  	#start: Drafts index/My drafts page
			describe "drafts index page" do
		  	it "should render my drafts page with only current authors drafts" do
		  		get :index
		  		response.body.should =~ /#{@draft_article3.draft.title.truncate(35)}/
		  	end

		  	it "should not render drafts of other agents" do
		  		get :index
		  		response.body.should_not =~ /#{@draft_article2.title.truncate(35)}/
		  	end
		  end
		  #end: Drafts index/My drafts page

		  #start: All drafts page
		  describe "all drafts page" do
		  	it "should display current users own drafts" do
		  		get :index, :type => :all
		  		response.body.should =~ /#{@draft_article3.draft.title.truncate(35)}/
		  	end

		  	it "should display other users drafts also" do
		  		get :index, :type => :all
		  		response.body.should =~ /#{@draft_article4.user.name}/
		  	end
		  end
		  #end: All drafts page
		end
		#end : specs for Views testing
	end
	  
end

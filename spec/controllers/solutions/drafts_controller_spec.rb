require 'spec_helper'

describe Solution::DraftsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  describe "Solution Drafts" do

	  before(:all) do
	  	@agent1 = add_test_agent
	  	@agent2 = add_test_agent
	  	@test_category_meta = create_category
	  	@public_folder_meta  = create_folder({:category_id => @test_category_meta.id })

	    @draft_article_meta1 = create_article({:folder_id => @public_folder_meta.id, :status => 1, :art_type => 1, :user_id => @agent1.id})
	    @draft_article_meta2 = create_article({:folder_id => @public_folder_meta.id, :status => 1, :art_type => 1, :user_id => @agent2.id})
	  	@draft_article1 = @draft_article_meta1.primary_article
	  	@draft_article2 = @draft_article_meta2.primary_article
	  end

	  #start : specs for index action
	  describe "index action" do

	  	before(:each) do
	  		log_in(@agent1)
	  	end

		  it "should render current author drafts listing if index is hit" do
		  	@agent1.make_current
		  	draft = @draft_article1.draft
		  	draft.title = "New sample title :  #{Faker::Name.name}"
		  	draft.save
		    get :index
		    response.body.should =~ /#{draft.title.truncate(35)}/
		    response.body.should_not =~ /#{@draft_article2.draft.title.truncate(35)}/
		  end

		  it "should render only the current author's drafts only" do
		    get :index
		    drafts = assigns(:drafts)
		    user_drafts_from_db = Account.current.solution_drafts.where(:user_id => @agent1.id).limit(10)
		    drafts.count.should be_eql(user_drafts_from_db.count)
		    drafts.map(&:id).should include(*user_drafts_from_db.map(&:id))
		  end

		  it "should render all drafts when visited all drafts path" do
		    get :index, :type => :all
		    drafts = assigns(:drafts)
		    all_drafts = Account.current.solution_drafts.limit(10)
		    drafts.size.should be_eql(all_drafts.size)
		  end
		end
		#end : specs for index action

		#start : specs for publish action
		describe "publish action" do

			before(:each) do
				log_in(@agent1)

				@draft_article_meta3 = create_article({:folder_id => @public_folder_meta.id, 
	      		:status => "1", :art_type => "1", :user_id => @agent1.id } )
	  		# @draft_article3.create_draft_from_article({:title => "Draft 1 for publish #{Faker::Name.name}", :description => "Desc 1 : #{Faker::Lorem.sentence(4)}"})
	  		@draft_article3 = @draft_article_meta3.primary_article
	  		request.env["HTTP_REFERER"] = "where_i_came_from"
	  	end

	  	it "should publish an unpublished article with a draft record" do
	  		@draft_article3.draft.should_not be_blank
	  		post :publish, :id => 1, :article_id => @draft_article_meta3.id, :language_id => @draft_article3.language_id
	  		response.should redirect_to "where_i_came_from"
	  		@draft_article3.reload
	  		@draft_article3.status.should be_eql(Solution::Article::STATUS_KEYS_BY_TOKEN[:published])
	  		@draft_article3.draft.should_not be_present
	  	end

	  	it "should not publish an unpublished article with draft record if it's locked" do
	  		log_in(@agent2)
	  		@agent2.make_current
	  		draft = @draft_article3.draft
	  		draft.lock_for_editing
	  		draft.save

	  		log_in(@agent1)
	  		@agent1.make_current
	  		#draft should be locked
	  		draft.locked?.should be_eql(true)
	  		#article should not be published
	  		@draft_article3.status.should_not be_eql(Solution::Article::STATUS_KEYS_BY_TOKEN[:published])

	  		post :publish, :id => 1, :article_id => @draft_article_meta3.id, :language_id => @draft_article3.language_id
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

	    	@draft_article_meta3 = create_article( { :folder_id => @public_folder_meta.id, 
	      		:status => "1", :art_type => "1", :user_id => @agent1.id } )
	    	@draft_article3 = @draft_article_meta3.primary_article
	  		request.env["HTTP_REFERER"] = "where_i_came_from"
	  	end

	  	it "should not have have flash message if there is no draft for an associated unpublished article" do
	  		@draft_article3.draft.destroy
	  		@draft_article3.reload
	  		delete :destroy, :article_id => @draft_article_meta3.id, :language_id => @draft_article3.language_id
	  		response.should redirect_to "where_i_came_from"
	  		flash[:notice].should be_nil
	  	end

	  	it "should delete a draft record" do
	  		@draft_article3.draft.should be_present
	  		delete :destroy, :article_id => @draft_article_meta3.id, :language_id => @draft_article3.language_id
	  		#should redirect to where i came from
	  		response.should redirect_to "where_i_came_from"
	  		#the succesfully discarded flash msg should be present
	  		expect(flash[:notice]).to be_present
	  		@draft_article3.reload
	  		#the draft should not be present
	  		@draft_article3.draft.should_not be_present
	  	end

	  	it "should not delete a draft record if it's locked" do
	  		log_in(@agent2)
	  		@agent2.make_current
	  		draft = @draft_article3.draft
	  		draft.lock_for_editing
	  		draft.save

	  		log_in(@agent1)
	  		@agent1.make_current
	  		#draft should be locked
	  		draft.locked?.should be_eql(true)

	  		delete :destroy, :article_id => @draft_article_meta3.id, :language_id => @draft_article3.language_id
	  		#should redirect to where you came from
	  		response.should redirect_to "where_i_came_from"
	  		#there should not be any flash message
	  		flash[:notice].should be_nil

	  		@draft_article3.reload
	  		#the draft of the article should exist
	  		@draft_article3.draft.should_not be_blank
	  	end


	  	it "should send a notification mail if draft is discard by somebody other than the author" do
	  		log_in(@agent2)
	  		@agent2.make_current
	  		draft = @draft_article3.draft
	  		draft.unlock
	  		draft.save

	  		log_in(@agent1)
	  		@agent1.make_current

	  		#draft should not be of the agent who discards draft
	  		draft.user_id.should_not be_eql(@agent1.id)

	  		delete :destroy, :article_id => @draft_article_meta3.id, :language_id => @draft_article3.language_id

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
				@draft_article_meta3 = create_article( {:title => "Article 3 attachment delete agent1[#{@agent1.id}] #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(2)}", :folder_id => @public_folder_meta.id, 
	      		:status => "1", :art_type => "1", :user_id => "#{@agent1.id}" } )
				@draft_article3 = @draft_article_meta3.primary_article
			end

			describe "for attachments" do
				before(:each) do
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

		  		delete :attachments_delete, :article_id => @draft_article_meta3.id, :attachment_type => :attachment, :attachment_id => @attachment.id, :language_id => @draft_article3.language_id

		  		draft.reload
		  		@draft_article3.reload
		  		@draft_article3.attachments.should be_present
		  		draft.deleted_attachments(:attachments).should be_eql([@attachment.id])
		  	end

		  	it "should soft delete the attachment from article draft when the attachment_type is invalid but resource is an attachment" do
		  		draft = @draft_article3.draft
		  		draft.should_not be_blank
		  		@draft_article3.attachments.should be_present
		  		delete :attachments_delete, :article_id => @draft_article_meta3.id, :attachment_type => 'test', :attachment_id => @attachment.id, :language_id => @draft_article3.language_id
		  		draft.reload
		  		@draft_article3.reload
		  		@draft_article3.attachments.should be_present
		  		draft.deleted_attachments(:attachments).should be_eql([@attachment.id])
		  	end
		  end

		  describe "for cloud_files" do
				before(:each) do
					@cloud_file = @draft_article3.cloud_files.build(:url => "https://www.dropbox.com/s/7d3z51nidxe358m/Getting Started.pdf?dl=0", 
						:application_id => 20, :filename => "Getting Started.pdf")
					@cloud_file.save
		  		request.env["HTTP_REFERER"] = "where_i_came_from"
	  		end

	  		it "should soft delete the attachment from article draft" do
		  		draft = @draft_article3.draft
		  		draft.should_not be_blank
		  		@draft_article3.cloud_files.should be_present
		  		delete :attachments_delete, :article_id => @draft_article_meta3.id, :attachment_type => 'cloud_file', :attachment_id => @cloud_file.id, :language_id => @draft_article3.language_id
		  		draft.reload
		  		@draft_article3.reload
		  		@draft_article3.cloud_files.should be_present
		  		draft.deleted_attachments(:cloud_files).should be_eql([@cloud_file.id])
		  	end

		  	it "should render 404 if attachment_type is invalid but resource is a cloud file" do
		  		draft = @draft_article3.draft
		  		draft.should_not be_blank
		  		@draft_article3.cloud_files.should be_present
		  		delete :attachments_delete, :article_id => @draft_article_meta3.id, :attachment_type => 'test', :attachment_id => @cloud_file.id, :language_id => @draft_article3.language_id
		  		response.code.should be_eql("404")
		  		@draft_article3.cloud_files.should be_present
		  		draft.deleted_attachments(:cloud_files).should be_eql([])
		  	end	
		  end

		end
		#end : specs for  attachment delete action

		#start : specs for autosave action
		describe "autosave action" do
			
			before(:each) do
				log_in(@agent1)
				@draft_article_meta3 = create_article( {:title => "Article 3 attachment delete agent1[#{@agent1.id}] #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(2)}", :folder_id => @public_folder_meta.id, 
	      		:status => "1", :art_type => "1", :user_id => "#{@agent1.id}" } )
				@draft_article3 = @draft_article_meta3.primary_article
	  		@draft = @draft_article3.draft
	  	end

	  	#Success case 1. Normal autosave happens
	  	it "should successfully autosave a draft content" do
	  		xhr :post, :autosave, :article_id => @draft_article_meta3.id, :title => "New", :description => "New Desc", :timestamp => @draft.updation_timestamp, :language_id => @draft_article3.language_id
	  		response.code.should be_eql("200")
	  		response.body.should =~ /Draft saved/
	  	end

	  	#Failure case 2. You are editing it from somewhere also
	  	it "should fail: Reason - You are editing it from somewhere" do
	  		xhr :post, :autosave, :article_id => @draft_article_meta3.id, :title => "New", :description => "New Desc", :timestamp => (@draft.updation_timestamp+23), :language_id => @draft_article3.language_id

	  		response.code.should be_eql("200")
	  		response.body.should =~ /You have updated the content elsewhere/
	  	end

	  	#Failure case 3. Somebody else is editing the article
	  	it "should fail: Reason - Somebody else is editing the article" do
	  		log_in(@agent2)
	  		@agent2.make_current
	  		@draft.lock_for_editing
	  		@draft.save

	  		log_in(@agent1)
	  		@agent1.make_current

	  		xhr :post, :autosave, :article_id => @draft_article_meta3.id, :title => "New", :description => "New Desc", :timestamp => @draft.updation_timestamp, :language_id => @draft_article3.language_id

	  		response.code.should be_eql("200")
	  		response.body.should =~ /#{@agent2.name} is currently editing/
	  	end

	  	#Failure case 4. Content has been updated by someone
	  	it "should fail: Reason - Content has been updated by someone" do
	  		log_in(@agent2)
	  		@agent2.make_current
	  		@draft.save

	  		log_in(@agent1)
	  		@agent1.make_current

				xhr :post, :autosave, :article_id => @draft_article_meta3.id, :title => "New", :description => "New Desc", :timestamp => @draft.updation_timestamp + 1, :language_id => @draft_article3.language_id
	  		response.code.should be_eql("200")
	  		response.body.should =~ /#{@agent2.name} has updated the content while you were away/
	  	end

	  end
		#end : specs for autosave action

		#Start : specs for Views testing
		describe "checking views" do
			
			before(:each) do
				log_in(@agent1)
				@agent1.make_current
				@account.solution_drafts.destroy_all
				@draft_article_meta3 = create_article( {:title => "Article 4 attachment delete agent1[#{@agent1.id}] #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(2)}", :folder_id => @public_folder_meta.id, 
	      		:status => "1", :art_type => "1", :user_id => "#{@agent1.id}" } )
				@draft_article3 = @draft_article_meta3.primary_article
	  		@draft = @draft_article3.draft
	  		log_in(@agent2)
	  		@agent2.make_current
	  		@draft_article_meta4 = create_article( {:title => "article5 agent2 #{@agent2.id} #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @public_folder_meta.id,
	      :status => "1", :art_type => "1", :user_id => "#{@agent2.id}" } )
	      log_in(@agent1)
	      @agent1.make_current
	  	end

	  	#start: Drafts index/My drafts page
			describe "drafts index page" do
		  	it "should render my drafts page with only current authors drafts" do
		  		get :index
		  		response.body.should =~ /#{@draft.title.truncate(35)}/
		  	end

		  	it "should not render drafts of other agents" do
		  		get :index
		  		response.body.should_not =~ /#{@draft_article_meta4.primary_article.draft.title.truncate(35)}/
		  	end
		  end
		  #end: Drafts index/My drafts page

		  #start: All drafts page
		  describe "all drafts page" do
		  	it "should display current users own drafts" do
		  		get :index, :type => :all
		  		response.body.should =~ /#{@draft.title.truncate(35)}/
		  	end

		  	it "should display other users drafts also" do
		  		get :index, :type => :all
		  		response.body.should =~ /#{@draft_article_meta4.primary_article.draft.title.truncate(35)}/
		  	end
		  end
		  #end: All drafts page
		end
		#end : specs for Views testing
	end
	  
end

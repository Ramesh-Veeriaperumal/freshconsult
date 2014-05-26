require 'spec_helper'

describe Helpdesk::CaFoldersController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

		before(:all) do
			@cr_folder = create_cr_folder({:name => "CR Folder"})
		end

		before(:each) do
			log_in(@agent)
		end

		it "should view the folder without canned responses" do
			get :show, :id => @cr_folder.id, :ticket_id => 1
			response.body.should =~ /No responses/
		end

		it "should view the folder with canned responses" do
			@test_response = create_response( {:title => "Folder Canned_Responses",:content_html => Faker::Lorem.paragraph,
				:folder_id => @cr_folder.id, :user_id => @agent.id, :visibility => 1, :group_id => 1  } )
			get :show, :id => @cr_folder.id, :ticket_id => 1
			response.body.should =~ /#{@test_response.title}/
		end
	end

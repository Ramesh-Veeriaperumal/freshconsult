require 'spec_helper'

describe Helpdesk::CaFoldersController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

		before(:all) do
			@cr_folder = create_cr_folder({:name => "CR Folder"})
			@ticket = create_ticket({:status => 2})
		end

		before(:each) do
			log_in(@agent)
		end

		it "should view the folder without canned responses" do
			get :show, :id => @cr_folder.id, :ticket_id => @ticket.display_id, :format => 'js'
			response.body.should =~ /No responses/
		end

		it "should view the folder with canned responses" do
			@test_response = create_response( {:title => "Folder Canned_Responses",:content_html => Faker::Lorem.paragraph,
				:folder_id => @cr_folder.id, :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]} )
			get :show, :id => @cr_folder.id, :ticket_id => @ticket.display_id, :format => 'js'
			response.body.should =~ /#{@test_response.title}/
		end
end

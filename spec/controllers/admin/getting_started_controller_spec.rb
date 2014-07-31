require 'spec_helper'

describe Admin::GettingStartedController do
	# integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:each) do
		login_admin
	end

	it "should display getting_started page" do
		get :index
		response.body.should =~ /Congrats! Your Freshdesk is ready!/
		response.should be_success
	end

	it "should rebrand the account" do
		put :rebrand, { :account=>{ 
				:main_portal_attributes=> { :name=>"Test Account", 
											:logo_attributes=>{:content=>
												Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png', 'image/png')}, 
											:preferences=>{:header_color=>"#252525", :tab_color=>"#006063", :bg_color=>"#efefef"},
											:id=> RSpec.configuration.account.id 
											}
									}
		}
		response.template.assigns["error"].should be_nil
		RSpec.configuration.account.main_portal.logo.should_not be_nil
		RSpec.configuration.account.main_portal.logo.content_file_name.should eql "image4kb.png"
	end

	it "should not allow invalid colors while rebranding" do
		put :rebrand, { :account=>{ 
				:main_portal_attributes=>{  :name=>"Test Account", 
											:logo_attributes=>{:content=>
												Rack::Test::UploadedFile.new('spec/fixtures/files/image33kb.jpg', 'image/jpg')}, 
											:preferences=>{:header_color=>"#252asa525", :tab_color=>"#00sd6063", :bg_color=>"#efsdsefef"},
											:id=> RSpec.configuration.account.id 
											}
									}
		}
		response.template.assigns["error"].should eql "Header color code is invalid."
		RSpec.configuration.account.main_portal.logo.content_file_name.should_not eql "image33kb.jpg"
		RSpec.configuration.account.main_portal.logo.content_file_name.should eql "image4kb.png"
	end

	it "should delete logo of the account" do
		delete :delete_logo
		RSpec.configuration.account.reload
		RSpec.configuration.account.main_portal.logo.should be_nil
	end
end
require 'spec_helper'

describe Admin::DynamicNotificationTemplatesController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do		
		@account = create_test_account
		@email_notifications = @account.email_notifications
		@test_notification = @email_notifications.find_by_notification_type("1")
		@test_notification.update_attributes({:outdated_requester_content => true})
		@test_translation = Factory.build(:dynamic_notification_templates)			
		@test_translation.save		
		@user = add_test_agent(@account)			
	end

	before(:each) do
		@request.host = @account.full_domain
		@request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
		                                    (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"		
		@sample_subject = Faker::Lorem.words(10).join(" ")
		@sample_message = Faker::Lorem.paragraphs(2).join(" ")	
		@request.env['HTTP_REFERER'] = '/categories'
		log_in(@user)		                                    
	end

	it "should create a new notification translation" do
		put :update, :dynamic_notification_template => { :language =>"10",
										:category =>"1", :active =>"true", :email_notification_id =>"3", 
										:subject=> "new Dutch subject", :description=>"new Dutch subject", :outdated=>"0"}
		@account.dynamic_notification_templates.find_by_language("10").subject.should eql "new Dutch subject" 			
	end

	it "should update a notification translation" do
		put :update, :id => @test_translation.id,
			:dynamic_notification_template =>{
				:description => "updated french new ticket notification",
				:subject => "updated french new ticket notification"
			}
		@test_translation.reload	
		@test_translation.subject.should eql "updated french new ticket notification"
	end	

	it "should make parent notification up-to-date" do
		@test_notification.dynamic_notification_templates.each do |n|
			n.update_attributes({:outdated => false})	
		end 		
		@test_notification.reload
		@test_notification.outdated_requester_content.should eql false		
	end	
	
end

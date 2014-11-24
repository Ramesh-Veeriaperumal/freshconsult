require 'spec_helper'

describe Admin::EmailNotificationsController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@email_notifications = @account.email_notifications
		@test_notification = @email_notifications.find_by_notification_type("1")		
		@test_reply_temp = @email_notifications.find_by_notification_type("15")
		@user1 = add_test_agent(@account)
		@user2 = add_test_agent(@account)
	end

	before(:each) do
		@sample_subject = Faker::Lorem.words(10).join(" ")
		@sample_message = Faker::Lorem.paragraphs(2).join(" ")
		@request.env['HTTP_REFERER'] = '/admin'
		login_admin
	end

	it "should list all corresponding notifications" do
		get :index
		response.should render_template("admin/email_notifications/index")
	end

	it "should edit an agent email_notification" do
		get :edit, :id => @test_notification.id, :type => "agent_template"
    	response.body.should =~ /Agent Notification/
    	put :update, :id => @test_notification.id, :agent => "1", :email_notification => { :agent_subject_template => @sample_subject,
                               																:agent_template => @sample_message
                             															 }
		@test_notification.reload
		@test_notification.agent_subject_template.should eql @sample_subject
		@test_notification.agent_template.should eql @sample_message
	end

	it "should edit an requester email_notification" do
		get :edit, :id => @test_notification.id, :type => "requester_template"
    	response.body.should =~ /Requester Notification/
    	put :update, :id => @test_notification.id, :requester => "1",
      :email_notification => { :requester_subject_template => @sample_subject,
                               :requester_template => @sample_message
                             }
		@test_notification.reload
		@test_notification.requester_subject_template.should eql @sample_subject
		@test_notification.requester_template.should eql @sample_message
	end

	it "should outdate requester translations" do
		@test_notification.dynamic_notification_templates.create( :language =>"5",
										:category =>"2", :active =>"true", :email_notification_id =>"3",
										:subject=> "new spanish subject", :description=>"new spanish subject", :outdated=>"0")
		put :update, :id => @test_notification.id, :requester => "1", :email_notification =>{}, :outdated => "yes"
		@test_notification.reload
		@test_notification.dynamic_notification_templates.reload
		@test_notification.dynamic_notification_templates.find_by_language("5").outdated.should eql true
	end

	it "should verify redirection was invalid urls" do
		get :edit, :id => @test_reply_temp.id, :type => "agent_template"
		flash[:notice] =~ /This notification does not exist/
	end

	it "should outdate agent translations" do
		@test_notification.dynamic_notification_templates.create( :language =>"6",
										:category =>"1", :active =>"true", :email_notification_id =>"3",
										:subject=> "new finnish subject", :description=>"new finnish subject", :outdated=>"0")
		put :update, :id => @test_notification.id, :agent => "1", :email_notification =>{}, :outdated => "yes"
		@test_notification.reload
		@test_notification.dynamic_notification_templates.reload
		@test_notification.dynamic_notification_templates.find_by_language("6").outdated.should eql true
	end

	it "should edit reply_template"	do
		get :edit, :id => @test_reply_temp.id, :type => "reply_template"
    	response.body.should =~ /Reply Templates/
    	put :update, :id => @test_reply_temp.id, :requester => "1", :email_notification => { :requester_template => @sample_message }
		@test_reply_temp.reload
		@test_reply_temp.requester_template.should eql @sample_message
	end

	it "should update agents" do
		put :update_agents, :id => @test_notification.id,
			:email_notification_agents => { :notifyagents_data => { @test_notification.id => [@user1.id,@user2.id]}.to_json },
			"notify_agents_#{@test_notification.id}" => [@user1.id,@user2.id]
		@test_notification.email_notification_agents.map(&:user_id).should eql [@user1.id,@user2.id]
	end

end

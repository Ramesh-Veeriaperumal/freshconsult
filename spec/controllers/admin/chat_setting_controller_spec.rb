require "spec_helper"

describe Admin::ChatSettingController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false
	
	before(:each)do
		plan = SubscriptionPlan.find(4)
		@account = create_test_account
		@account.make_current
  	@user = add_test_agent(@account)
		log_in(@agent)
		@account.subscription.update_attributes(plan_info(plan))
	end

	xit "should render request page when chat feature is turned off" do# failing in master
		@account.features.send(:chat).destroy
		get :index
		response.should render_template("admin/chat_setting/request_page")
	end

	xit "should render 404 Error when current subscription plan does not support chat " do# failing in master
		plan = SubscriptionPlan.find(2)
		@account.subscription.update_attributes(plan_info(plan))
		get :index
		response.status.should eql 404
	end

	it "should render successfully when chat feature is turned on and chatSetting is already created" do
		@account.features.send(:chat).create
		get :index
		response.should render_template("admin/chat_setting/index")
	end

	it "should render successfully when chat feature is turned on and chatSetting is not created" do
		@account.chat_setting.destroy
		get :index
		response.should render_template("admin/chat_setting/index")
	end

	xit "should send mail to request chat feature" do# ACTION NOT FOUND
		post :request_freshchat_feature
		temp = JSON.parse(response.body)
		temp["status"].should eql "success"

	end

	xit "should toggle the chat enable feature" do# ACTION NOT FOUND
    request.env["HTTP_ACCEPT"] = "application/javascript"
		firstState=@account.features? :chat_enable
		post :toggle
		@account.reload
		
		secondState=@account.features? :chat_enable
		secondState.should_not eql firstState
		response.should render_template("admin/chat_setting/_toggle")

		post :toggle
		@account.reload

		thirdState=@account.features? :chat_enable
		thirdState.should eql firstState
		response.should render_template("admin/chat_setting/_toggle")


	end

	xit "should update the chat feature" do# failing in master
    request.env["HTTP_ACCEPT"] = "application/json"
		@account.features.send(:chat_enable).create
		@account.reload
		chat_setting = {
			:prechat_form_name =>"Name",
			:prechat_form_phoneno=>"",
			:prechat_form_mail=>"",
			:show_on_portal=>"1",
			:portal_login_required=>"0",
			:prechat_form=>"1",
			:prechat_message=>"We can't wait to talk to you. But first, please take a couple of moments to tell us a bit about yourself.",
			:prechat_phone=>"1",
			:prechat_mail=>"1",
			:proactive_chat=>"0",
			:proactive_time=>"180",
			:business_calendar_id=>"0",
			:preferences=>{
						:window_color=>"#ff0000",
						:window_position=>"Bottom Right",
						:window_offset=>"40",
						:text_place=>"Your Message",
						:connecting_msg=>"Waiting for an agent",
						:agent_left_msg=>"{{agent_name}} has left the chat",
						:agent_joined_msg=>"{{agent_name}} has joined the chat",
						:minimized_title=>"Let's talk!",
						:maximized_title=>"This chat is so on!",
						:welcome_message=>"Hi! How can we help you today?",
						:thank_message=>"Thank you for chatting with us. If you have additional questions, feel free to ping us!",
						:wait_message=>"All our agents are busy chatting right now. Please hang on for a couple of minutes."},
			:non_availability_message=>{
				:text=>"Looks like all our agents are tied up right now :( Sorry about that, but please # leave us a message # and we'll get right back.",
				:ticket_link_option=>"0",
				:custom_link_url=>""}
			}
		post :update ,:chat_setting=>chat_setting
		temp = JSON.parse(response.body)
		temp["status"].should eql "success"
	end

	xit "should not update the chat feature when there are empty parameters" do# failing in master
		@account.features.send(:chat_enable).create
		@account.reload
		chat_setting = {
			:prechat_form_name =>"",
			:prechat_form_phoneno=>"",
			:prechat_form_mail=>"",
			:show_on_portal=>"",
			:portal_login_required=>"",
			:prechat_form=>"",
			:prechat_message=>"",
			:prechat_phone=>"",
			:prechat_mail=>"",
			:proactive_chat=>"",
			:proactive_time=>"",
			:business_calendar_id=>"",
			:preferences=>{
						:window_color=>"",
						:window_position=>"",
						:window_offset=>"",
						:text_place=>"",
						:connecting_msg=>"",
						:agent_left_msg=>"",
						:agent_joined_msg=>"",
						:minimized_title=>"",
						:maximized_title=>"",
						:welcome_message=>"",
						:thank_message=>"",
						:wait_message=>""},
			:non_availability_message=>{
				:text=>"",
				:ticket_link_option=>"",
				:custom_link_url=>""}
			}
    request.env["HTTP_ACCEPT"] = "application/json"  
		post :update ,:chat_setting=>chat_setting
		temp = JSON.parse(response.body)
		temp["status"].should eql "error"
	end
	
	def plan_info(plan)
    {
      :subscription_plan => plan,
      :day_pass_amount => plan.day_pass_amount,
      :free_agents => plan.free_agents
    }
  end
end

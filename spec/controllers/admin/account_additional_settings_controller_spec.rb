require 'spec_helper'

describe Admin::AccountAdditionalSettingsController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:each) do
		login_admin
	end

	it "should display automatic Bcc email form" do
		post :assign_bcc_email
		response.body.should =~ /Bcc address/
		response.should be_success
	end

	it "should update the account_additional_settings" do
		test_email = Faker::Internet.email
		put :update, {
			:account_additional_settings =>{ :bcc_email=> test_email }
		}
		@account.reload
		@account.account_additional_settings.bcc_email.should eql(test_email)
		session[:flash][:notice].should eql "Successfully updated Bcc email"
		response.should redirect_to("/admin/email_configs")
	end

	it "should update the font settings in account_additional_settings" do
    request.env["HTTP_ACCEPT"] = "application/javascript"
		put :update_font, {
			"font-family" => 'times new roman, serif'
		}
		@account.reload
		@email_template = @account.account_additional_settings.email_template_settings
		@email_template["font-family"].should be_eql('times new roman, serif')
		response.should render_template("admin/email_notifications/_fontsettings")
	end

	it "should not update the account_additional_settings without emailId" do
		text = Faker::Name.name
		put :update, {
			:account_additional_settings =>{ :bcc_email=> text }
		}
		@account.reload
		@account.account_additional_settings.bcc_email.should_not eql(text)
		session[:flash][:notice].should eql "Failed to update Bcc email"
		response.should redirect_to("/admin/email_configs")
	end
	
	context "For Dynamic Content feature" do
		before(:all) do
			@account.features.dynamic_content.create unless @account.features?(:dynamic_content)
			@template_eng = create_dynamic_notification_template({:language => :en, :email_notification_id => 3})
			@template_ca = create_dynamic_notification_template({:language => :ca, :email_notification_id => 2})
			@account.account_additional_settings.update_attributes({:supported_languages => ["en", "tr"]})
		end
		
		before(:each) do
			@account.reload
		end
	
		it "should add or remove the support languages" do
			changed_languages = ["fi","cs","ca"]
			put :update, {
				:account_additional_settings => {
					:supported_languages =>  ["fi","cs","ca"]
				}
			}
			@account.reload
			@account.account_additional_settings.supported_languages.should eql(changed_languages)
			@account.dynamic_notification_templates.find_by_language(@template_eng.language).active.should be false
			@account.dynamic_notification_templates.find_by_language(@template_ca.language).active.should be true
			
      expect(response).to redirect_to("/admin/email_configs")
		end
	end
end
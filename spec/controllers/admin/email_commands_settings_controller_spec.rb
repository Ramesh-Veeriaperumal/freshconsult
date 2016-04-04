require 'spec_helper'

describe Admin::EmailCommandsSettingsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should go to the index page" do
    get 'index'
    response.should render_template "admin/email_commands_settings/index"
  end

  it "should edit the delimiter for email commands" do
    get 'index'
    put :update, :account_additional_settings => { :email_cmds_delimeter => "@freshsays" }
    @account.account_additional_settings.reload
    @account.account_additional_settings.email_cmds_delimeter.should be_eql("@freshsays")
    flash[:notice].should be_eql(I18n.t(:'email_commands_update_success'))
  end

end

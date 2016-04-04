require 'spec_helper'

describe Admin::TemplatesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should render the show page" do
    @agent.make_current
    get :show, :portal_id => @account.main_portal.id
    assigns(:portal_template).should_not be_nil
    assigns(:portal).should be_eql(@account.main_portal)
  end

  it "should update the portal with the customized changes" do
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge({:bg_color => color})
    put :update, :portal_id => @account.main_portal.id,
                 :portal_tab => "preferences",
                 :portal_template => { :preferences => updated_preferences }
    @account.main_portal.template.get_draft.preferences["bg_color"].should be_eql(color)
  end

  it "should update and publish the portal with the customized changes" do
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge({:bg_color => color})
    put :update, :portal_id => @account.main_portal.id,
                 :portal_tab => "preferences",
                 :publish_button => "Save and Publish",
                 :portal_template => { :preferences => updated_preferences }
    @account.reload
    @account.main_portal.template.get_draft.should be_nil
    @account.main_portal.template.preferences[:bg_color].should be_eql(color)
  end

  it "should update the portal with the customized changes and preview it" do
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge({:bg_color => color})
    put :update, :portal_id => @account.main_portal.id,
                 :portal_tab => "preferences",
                 :preview_button => "Preview",
                 :portal_template => { :preferences => updated_preferences }
    @account.main_portal.template.get_draft.preferences["bg_color"].should be_eql(color)
    response.should redirect_to("http://#{@account.full_domain}/support/preview")
    get :clear_preview, :portal_id => @account.main_portal.id
    response.body.should be_eql("success")
  end

  it "should publish the portal with the customized changes" do
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge({:bg_color => color})
    put :update, :portal_id => @account.main_portal.id,
                 :portal_tab => "preferences",
                 :portal_template => { :preferences => updated_preferences }
    @account.main_portal.template.preferences[:bg_color].should_not be_eql(color)
    get :publish, :portal_id => @account.main_portal.id
    @account.reload
    @account.main_portal.template.preferences[:bg_color].should be_eql(color)
  end
  
  it "should reset the portal to last-published" do
    initial_color = @account.main_portal.template.preferences[:bg_color]
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge({:bg_color => color})
    put :update, :portal_id => @account.main_portal.id,
                 :portal_tab => "preferences",
                 :portal_template => { :preferences => updated_preferences }
    put :soft_reset, :portal_id => @account.main_portal.id,
                     :portal_tab => "preferences",
                     :portal_template => ["preferences"]
    @account.reload
    @account.main_portal.template.get_draft.should be_nil
    @account.main_portal.template.preferences[:bg_color].should be_eql(initial_color)
  end

  it "should reset the portal to default preferences" do
    color = @account.main_portal.preferences[:bg_color]
    get :restore_default, :portal_id => @account.main_portal.id
    @account.reload
    @account.main_portal.template.preferences[:bg_color].should be_eql(color)
  end
end

require 'spec_helper'

RSpec.describe Freshfone::IvrsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
    log_in(@agent)
  end

  after(:each) do
    @account.freshfone_numbers.delete_all
  end

  it 'should render the number for ivr on show' do
    ivr = @number.ivr
    get :show, {:id => ivr.id}
    response.should redirect_to("/admin/phone/numbers/#{@number.id}/edit")
  end

  it 'should return all ivrs for the account' do
    get :index
    assigns[:ivrs].map(&:freshfone_number_id).should include @number.id
  end

  it 'should return ivr object for edit and redirect to edit template' do
    get :edit, {:id => @number.ivr.id}
    assigns[:ivr].freshfone_number_id.should be_eql(@number.id)
    response.should render_template("freshfone/ivrs/edit")
  end

  it 'should successfully update the welcome message on update action with json format' do
    message = Faker::Company.catch_phrase
    Freshfone::Ivr.any_instance.stubs(:unused_attachments).returns(@account.ivrs)
    params = {"freshfone_ivr"=>{"relations"=>"{\"0\":[]}", "message_type"=>"1", "ivr_data"=>{"0"=>{"menu_name"=>"Welcome/Start Menu", "menu_id"=>"0", "message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>message, "options"=>{"0"=>{"respond_to_key"=>"1", "performer"=>"User", "performer_id"=>"1", "performer_number"=>""}}}}}, "preview"=>"false", "format"=>"json", "id"=>@number.ivr.id}
    ivr = @number.ivr
    put :update, params
    @account.ivrs.find(ivr.id).menus.first.message.should be_eql(message)
    json.should be_eql(:status => "success")
  end

  it 'should successfully update the welcome message on update action with html format' do
    message = Faker::Company.catch_phrase
    Freshfone::Ivr.any_instance.stubs(:unused_attachments).returns(@account.ivrs)
    params = {"freshfone_ivr"=>{"relations"=>"{\"0\":[]}", "message_type"=>"1", "ivr_data"=>{"0"=>{"menu_name"=>"Welcome/Start Menu", "menu_id"=>"0", "message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>message, "options"=>{"0"=>{"respond_to_key"=>"1", "performer"=>"User", "performer_id"=>"1", "performer_number"=>""}}}}}, "preview"=>"false", "id"=>@number.ivr.id}
    ivr = @number.ivr
    put :update, params
    @account.ivrs.find(ivr.id).menus.first.message.should be_eql(message)
    response.should redirect_to("/admin/phone/numbers/#{@number.id}")
  end

  it 'should not update the welcome message on preview' do
    message = Faker::Company.catch_phrase
    params = {"freshfone_ivr"=>{"relations"=>"{\"0\":[]}", "message_type"=>"1", "ivr_data"=>{"0"=>{"menu_name"=>"Welcome/Start Menu", "menu_id"=>"0", "message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>message, "options"=>{"0"=>{"respond_to_key"=>"1", "performer"=>"User", "performer_id"=>"1", "performer_number"=>""}}}}}, "preview"=>"true", "format"=>"json", "id"=>@number.ivr.id}
    ivr = @number.ivr
    put :update, params
    @account.ivrs.find(ivr.id).menus.first.message.should_not be_eql(message)
  end

  it 'should not update the welcome message on update failure with json format' do
    message = Faker::Company.catch_phrase
    Freshfone::Ivr.any_instance.stubs(:update_attributes).returns(false)
    params = {"freshfone_ivr"=>{"relations"=>"{\"0\":[]}", "message_type"=>"1", "ivr_data"=>{"0"=>{"menu_name"=>"Welcome/Start Menu", "menu_id"=>"0", "message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>message, "options"=>{"0"=>{"respond_to_key"=>"1", "performer"=>"User", "performer_id"=>"1", "performer_number"=>""}}}}}, "preview"=>"true", "format"=>"json", "id"=>@number.ivr.id}
    ivr = @number.ivr
    put :update, params
    @account.ivrs.find(ivr.id).menus.first.message.should_not be_eql(message)
    json.should have_key(:error_message)
  end

  it 'should not update the welcome message on update failure with html format' do
    message = Faker::Company.catch_phrase
    Freshfone::Ivr.any_instance.stubs(:update_attributes).returns(false)
    params = {"freshfone_ivr"=>{"relations"=>"{\"0\":[]}", "message_type"=>"1", "ivr_data"=>{"0"=>{"menu_name"=>"Welcome/Start Menu", "menu_id"=>"0", "message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>message, "options"=>{"0"=>{"respond_to_key"=>"1", "performer"=>"User", "performer_id"=>"1", "performer_number"=>""}}}}, "attachments"=>{"0"=>{"content"=>"#<File:/var/folders/66/tpd2l9td1fb5tqggls39r59w0000gn/T/RackMultipart20140527-28095-1kivk1a>"}}}, "preview"=>"true", "id"=>@number.ivr.id}
    ivr = @number.ivr
    put :update, params
    @account.ivrs.find(ivr.id).menus.first.message.should_not be_eql(message)
    response.should render_template("admin/freshfone/numbers/edit")
  end

  it 'should enable ivr on successful activate action' do
    ivr = @number.ivr.reload
    ivr.update_attributes(:active => false)
    post :activate, {:id => @number.ivr.id, :active => true}
    @account.ivrs.find(ivr.id).should be_active
  end

  it 'should not enable ivr on unsuccessful activate action' do
    ivr = @number.ivr.reload
    ivr.update_attributes(:active => false)
    Freshfone::Ivr.any_instance.stubs(:update_attributes).returns(false)
    post :activate, {:id => @number.ivr.id, :active => true}
    @account.ivrs.find(ivr.id).should_not be_active
  end

  it 'should disable ivr on successful deactivate action' do
    ivr = @number.ivr
    ivr.update_attributes(:active => true)
    post :deactivate, {:id => @number.ivr.id, :active => false}
    @account.ivrs.find(ivr.id).should_not be_active
  end

  it 'should not disable ivr on unsuccessful deactivate action' do
    ivr = @number.ivr.reload
    ivr.update_attributes(:active => true)
    Freshfone::Ivr.any_instance.stubs(:update_attributes).returns(false)
    post :deactivate, {:id => @number.ivr.id, :active => false}
    @account.ivrs.find(ivr.id).should be_active
  end

  it 'should destroy ivr on destroy action' do
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio)
    number = @account.freshfone_numbers.create!( :number => Faker::PhoneNumber.phone_number, 
      :display_number => "+1234567890", :country => "US", :region => "Texas", :number_type => 1 )
    post :destroy, {:id => number.ivr.id}
    @account.freshfone_numbers.find(number.id).ivr.should be_nil
  end

  it 'should not destroy ivr on destroy action' do
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio)
    Freshfone::Ivr.any_instance.stubs(:destroy).returns(false)
    number = @account.freshfone_numbers.create!( :number => Faker::PhoneNumber.phone_number, 
      :display_number => "+1234567890", :country => "US", :region => "Texas", :number_type => 1 )
    post :destroy, {:id => number.ivr.id}
    @account.freshfone_numbers.find(number.id).ivr.should_not be_nil
  end

end
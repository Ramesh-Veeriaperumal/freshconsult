require 'spec_helper'

describe Admin::Freshfone::NumbersController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
    log_in(@agent)
  end

  it 'should return all freshfone numbers on index' do
    number = @account.freshfone_numbers.first
    get :index
    # assigns[:account].app_id.should be_eql(@account.freshfone_account.app_id)
    assigns[:numbers].map(&:number).should include number.number
    response.should render_template "admin/freshfone/numbers/index"
  end

  it 'should create a new number on purchase' do
    @num = Faker::PhoneNumber.phone_number
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio)
    params = { :phone_number => @num, :formatted_number => @num, 
               :region => "Texas", :country => "US", :type => 'local', :number_sid => "PNUMBER" }
    post :purchase, params
    assigns[:purchased_number].number.should be_eql(@num)
    flash[:notice].should be_eql("Successfully purchased phone number.")
  end

  it 'should allow only one number for purchase on phone trial' do
    @account.freshfone_numbers.destroy_all
    load_freshfone_trial
    @num = Faker::PhoneNumber.phone_number
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio)
    params = { :phone_number => @num, :formatted_number => @num,
               :region => "Texas", :country => "US", :type => "local", :number_sid => "PNUMBER", :subscription => "trial" }
    post :purchase, params
    expect(assigns[:purchased_number].number).to eq(@num)
    expect(flash[:notice]).to eq(I18n.t('flash.freshfone.number.successful_purchase'))

    @num = Faker::PhoneNumber.phone_number
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio)
    params = { :phone_number => @num, :formatted_number => @num,
               :region => "Texas", :country => "US", :type => "local", :number_sid => "PNUMBER", :subscription => "trial" }
    post :purchase, params
    expect(flash[:notice]).to eq(I18n.t('freshfone.admin.trial.request_activation_msg'))
  end

  it 'should not allow numbers whose rate are more than 1$ in trial' do
    @account.freshfone_numbers.destroy_all
    load_freshfone_trial
    @num = Faker::PhoneNumber.phone_number
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio)
    params = { :phone_number => @num, :formatted_number => @num, 
               :region => "Texas", :country => "US", :type => 'toll_free', :number_sid => "PNUMBER" }
    post :purchase, params
    expect(flash[:notice]).to eq(I18n.t('freshfone.admin.trial.request_activation_msg'))
  end

  it 'should allow numbers whose rate are of 2$ if configured in trial' do
    @account.freshfone_subscription.destroy if @account.freshfone_subscription.present?
    @account.freshfone_numbers.destroy_all
    @account.freshfone_account.update_column(:state, Freshfone::Account::STATE_HASH[:trial])
    create_test_freshfone_subscription(number_credit: 2)
    @num = Faker::PhoneNumber.phone_number
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio)
    params = { :phone_number => @num, :formatted_number => @num,
      :region => "Texas", :country => "US", :type => "toll_free", :number_sid => "PNUMBER"}
    post :purchase, params
    expect(flash[:notice]).to eq(I18n.t('flash.freshfone.number.successful_purchase'))
  end

  it 'should create a new address required number on purchase' do
    @num = Faker::PhoneNumber.phone_number
    create_ff_address
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio)
    params = { :phone_number => @num, :formatted_number => @num, 
               :region => "Texas", :country => "DE", :type => 'local', :number_sid => "PNUMBER", :address_required => true }
    ff_address_inspect(params[:country])
    post :purchase, params 
    assigns[:purchased_number].number.should be_eql(@num)
    flash[:notice].should be_eql("Successfully purchased phone number.")
  end

  it 'should not create a new address required number on purchase if the provided address has incorrect postal code' do
    @num = Faker::PhoneNumber.phone_number
    @account.freshfone_account.freshfone_addresses.destroy_all
    create_ff_address('Post_ABCD')
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio)
    params = { :phone_number => @num, :formatted_number => @num, 
               :region => "Texas", :country => "AU", :type => 'local', :number_sid => "PNUMBER", :address_required => 'true' }
    ff_address_inspect(params[:country])
    post :purchase, params
    json[:errors].first.should be_eql("Unable to purchase number. Kindly make sure the address is a valid local address in Australia.")
  end

  it 'should not create a new address required number on purchase if freshfone_address not exist' do
    @num = Faker::PhoneNumber.phone_number
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio).raises(StandardError.new("PhoneNumber Requires a Local Address"))
    params = { :phone_number => @num, :formatted_number => @num, 
               :region => "Texas", :country => "AU", :type => 'local', :number_sid => "PNUMBER", :address_required => true }
    ff_address_inspect(params[:country])
    Admin::Freshfone::NumbersController.any_instance.stubs(:verify_address)
    post :purchase, params
    assigns[:purchased_number].should be_new_record
    flash[:notice].should be_eql("Error purchasing phone number.")
  end

  it 'should not create a number on validation failure, passing nil to number' do
    @num = Faker::PhoneNumber.phone_number
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio)
    params = { :phone_number => nil, :formatted_number => @num, 
               :region => "Texas", :country => "US", :type => 'local', :number_sid => "PNUMBER" }
    post :purchase, params
    flash[:notice].should be_eql("Number can't be blank")
  end

  it 'should not create a number on exception' do
    @num = Faker::PhoneNumber.phone_number
    params = { :phone_number => @num, :formatted_number => @num, 
               :region => "Texas", :country => "US", :type => 'local', :number_sid => "PNUMBER" }
    post :purchase, params
    assigns[:purchased_number].should be_new_record
    flash[:notice].should be_eql("Error purchasing phone number.")
  end  

  it 'should load number and redirect to number on show' do
    get :show, {:id => @number.id}
    response.should redirect_to("/admin/phone/numbers/#{@number.id}/edit")
  end

  it 'should update name for the number' do
    name = Faker::Name.name
    # controller.stubs(:unused_attachments).returns(true)
    Freshfone::Number.any_instance.stubs(:unused_attachments).returns(@account.freshfone_numbers)
    params = {"admin_freshfone_number"=>{"name"=>name, "record"=>"true", "voice"=>"0", 
      "non_availability_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"unavailable"}, "max_queue_length"=>"3", "queue_wait_time"=>"2", 
      "on_hold_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"Busy"}, "non_business_hours_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"",
      "message"=>"not working"},
      "wait_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "hold_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "voicemail_active"=>"true", 
      "voicemail_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>"test"}}, 
      "non_business_hour_calls"=>"true", "business_calendar"=>"1",  "access_groups_added_list"=>"2,3",
       "access_groups_removed_list"=>"1", "id"=>@number.id}
    put :update, params
    @account.freshfone_numbers.find(@number).name.should be_eql(name)
  end

  it 'should update groups for the number' do
    name = Faker::Name.name
    # controller.stubs(:unused_attachments).returns(true)
    Freshfone::Number.any_instance.stubs(:unused_attachments).returns(@account.freshfone_numbers)
    params = {"admin_freshfone_number"=>{"name"=>name, "record"=>"true", "voice"=>"0", 
      "non_availability_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"unavailable"}, "max_queue_length"=>"3", "queue_wait_time"=>"2", 
      "on_hold_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"Busy"}, "non_business_hours_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"",
      "message"=>"not working"},
      "wait_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "hold_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "voicemail_active"=>"true", 
      "voicemail_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>"test"}}, 
      "non_business_hour_calls"=>"true", "business_calendar"=>"1", "access_groups_added_list"=>"1",
       "access_groups_removed_list"=>"2,3", "id"=>@number.id}
    put :update, params
    accessible_numbers = accessible_groups(@account.freshfone_numbers.find(@number))
    p "accessible_numbers => #{accessible_numbers}"
    accessible_numbers.should be_eql([1])
  end

  it 'should not update number for invalid queue length' do#TODO-RAILS3 possible dead code
    name = Faker::Name.name
    params = {"admin_freshfone_number"=>{"name"=>name, "record"=>"true", "voice"=>"0", 
      "non_availability_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"unavailable"}, "max_queue_length"=>"13", "queue_wait_time"=>"2", 
      "on_hold_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"Busy"}, "non_business_hours_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"",
      "message"=>"not working"},
      "wait_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "hold_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "voicemail_active"=>"true", 
      "voicemail_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>"test"}}, 
      "non_business_hour_calls"=>"false", "business_calendar"=>"1", "id"=>@number.id}
    put :update, params
    @account.freshfone_numbers.find(@number).name.should_not be_eql(name)
  end

  it 'should not update number for invalid queue length and return error json' do
    name = Faker::Name.name
    params = {"admin_freshfone_number"=>{"name"=>name, "record"=>"true", "voice"=>"0", 
      "non_availability_message"=>{"message_type"=>"1", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"unavailable to take your call right now"}, 
      "attachments"=>{"non_availability_message"=>{
      "content"=>"#<File:/var/folders/66/tpd2l9td1fb5tqggls39r59w0000gn/T/RackMultipart20140526-28095-1i27dme>"}}, 
      "max_queue_length"=>"13", "queue_wait_time"=>"2", 
      "on_hold_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"Busy"}, "non_business_hours_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"",
      "message"=>"not working"},
      "wait_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "hold_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "voicemail_active"=>"true", 
      "voicemail_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>"test"}}, 
      "non_business_hour_calls"=>"false", "id"=>@number.id, "format" => "json"}
    put :update, params
    @account.freshfone_numbers.find(@number).name.should_not be_eql(name)
    json.should have_key(:error_message)
  end

  it 'should remove the attachment for wait message' do
    name = Faker::Name.name
    params = {"admin_freshfone_number"=>{"name"=>name, "record"=>"true", "voice"=>"0", 
      "non_availability_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"unavailable"}, 
      "max_queue_length"=>"0", "queue_wait_time"=>"2", 
      "on_hold_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"Busy"}, "non_business_hours_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"",
      "message"=>"not working"},
      "wait_message" => {"message_type" => "1", "attachment_id" => ""},
      "hold_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "voicemail_active"=>"true", 
      "voicemail_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>"test"}}, 
      "non_business_hour_calls"=>"false", "business_calendar"=>"1","access_groups_added_list"=>"1",
       "access_groups_removed_list"=>"2,3", "id"=>@number.id}
    put :update, params
   
    @account.freshfone_numbers.find(@number).wait_message.attachment_id.should be_nil
    @account.freshfone_numbers.find(@number).wait_message.message_type.should be_eql(1)
  end

  it 'should remove the attachment for hold message' do
    name = Faker::Name.name
    params = {"admin_freshfone_number"=>{"name"=>name, "record"=>"true", "voice"=>"0", 
      "non_availability_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"unavailable"}, 
      "max_queue_length"=>"0", "queue_wait_time"=>"2", 
      "on_hold_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"Busy"}, "non_business_hours_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"",
      "message"=>"not working"},
      "wait_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "hold_message" => {"message_type" => "1", "attachment_id" => ""},
      "voicemail_active"=>"true", 
      "voicemail_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>"test"}}, 
      "non_business_hour_calls"=>"false", "business_calendar"=>"1","access_groups_added_list"=>"1",
       "access_groups_removed_list"=>"2,3", "id"=>@number.id}
    put :update, params
  
    @account.freshfone_numbers.find(@number).hold_message.attachment_id.should be_nil
    @account.freshfone_numbers.find(@number).hold_message.message_type.should be_eql(1)
  end

  it 'should soft delete freshfone number' do
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio)
    Freshfone::NumberObserver.any_instance.stubs(:delete_from_twilio)
    number = @account.freshfone_numbers.create!( :number => Faker::PhoneNumber.phone_number, :display_number => "+1234567890", 
                  :country => "US", :region => "Texas", :number_type => 1 )
    post :destroy, {:id => number.id}
    @account.all_freshfone_numbers.find(number.id).should be_deleted
    @account.all_freshfone_numbers.find(number.id).delete
  end

  it 'should not delete freshfone number on exception' do
    Freshfone::NumberObserver.any_instance.stubs(:add_number_to_twilio)
    Freshfone::NumberObserver.any_instance.stubs(:delete_from_twilio)
    Freshfone::Number.any_instance.stubs(:update_attributes)
    number = @account.freshfone_numbers.create!( :number => Faker::PhoneNumber.phone_number, :display_number => "+1234567890", 
                  :country => "US", :region => "Texas", :number_type => 1 )
    post :destroy, {:id => number.id}
    @account.all_freshfone_numbers.find(number.id).should_not be_deleted
    @account.all_freshfone_numbers.find(number.id).delete
  end

  it 'should display low balance message for zero credits on edit action' do
    @credit.update_attributes(:available_credit => 0)
    get :edit
    flash[:notice].should be_eql("Your phone channel has been suspended due to low balance. Please recharge to activate.")
    response.should redirect_to("/admin/phone/numbers")
  end

  it 'should display suspended message and not allow edit when suspended' do
    Freshfone::Account.any_instance.stubs(:suspended?).returns(true)
    get :edit
    flash[:notice].should be_eql("Your phone channel is currently suspended. Please enable phone to make and receive calls.")
    response.should redirect_to("/admin/phone/numbers")
  end
  
  it 'should update outgoing caller for the number' do
    create_freshfone_outgoing_caller
    Freshfone::Number.any_instance.stubs(:unused_attachments).returns(@account.freshfone_numbers)
    params = {"admin_freshfone_number"=>{"record"=>"true", "voice"=>"0", 
      "non_availability_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"unavailable"}, "max_queue_length"=>"3", "queue_wait_time"=>"2", 
      "on_hold_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"Busy"}, "non_business_hours_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"",
      "message"=>"not working"},
      "wait_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "hold_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "voicemail_active"=>"true", 
      "voicemail_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>"test"}}, 
      "non_business_hour_calls"=>"true", "business_calendar"=>"1",  "access_groups_added_list"=>"2,3",
       "access_groups_removed_list"=>"1", "id"=>@number.id, :callmask_active => "true", :caller_id => @outgoing_caller.id}
    put :update, params
    Freshfone::Number.find_by_caller_id(@outgoing_caller.id).should_not == nil
  end

  it 'should not update outgoing caller for the number' do
    create_freshfone_outgoing_caller
    Freshfone::Number.any_instance.stubs(:unused_attachments).returns(@account.freshfone_numbers)
    params = {"admin_freshfone_number"=>{"record"=>"true", "voice"=>"0", 
      "non_availability_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"unavailable"}, "max_queue_length"=>"3", "queue_wait_time"=>"2", 
      "on_hold_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", 
      "message"=>"Busy"}, "non_business_hours_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"",
      "message"=>"not working"},
      "wait_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "hold_message" => {"message_type" => "1", "recording_url" => "http://google.com/123.mp3", "attachment_id" => "", "message" => ""},
      "voicemail_active"=>"true", 
      "voicemail_message"=>{"message_type"=>"2", "recording_url"=>"", "attachment_id"=>"", "message"=>"test"}}, 
      "non_business_hour_calls"=>"true", "business_calendar"=>"1",  "access_groups_added_list"=>"2,3",
       "access_groups_removed_list"=>"1", "id"=>@number.id}
    put :update, params
    Freshfone::Number.find_by_caller_id(@outgoing_caller.id).should == nil
  end

end
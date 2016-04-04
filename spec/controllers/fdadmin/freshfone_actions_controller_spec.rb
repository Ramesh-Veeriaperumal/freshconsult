require 'spec_helper'
load 'spec/support/freshfone_spec_helper.rb'
load 'spec/support/freshfone_actions_spec_helper.rb'
include FreshfoneActionsSpecHelper

describe Fdadmin::FreshfoneActionsController do
	self.use_transactional_fixtures = false

	Fdadmin::FreshfoneActionsController.skip_before_filter :verify_signature
	Fdadmin::FreshfoneActionsController.skip_before_filter :check_freshops_subdomain

	before :each do
		@account = Account.first
		create_test_freshfone_account
	end

	after :each do
		@account.freshfone_account.update_column(:security_whitelist, true)
		@account.freshfone_account.freshfone_usage_triggers.delete_all
	end

	it 'should remove daily threshold triggers when security whitelisted' do
		create_test_usage_triggers
		@account.freshfone_account.update_column(:security_whitelist, false)
		Twilio::REST::Trigger.any_instance.stubs(:delete)
		Resque.inline = true
		put :trigger_whitelist, { :account_id => @account.id, :name_prefix => "fdadmin_", :path_prefix => nil }
		Resque.inline = false
		@account.freshfone_account.reload
		@account.freshfone_account.freshfone_usage_triggers.reload
		expect(@account.freshfone_account.freshfone_usage_triggers).to be_blank
		expect(@account.freshfone_account.security_whitelist).to be true
		Twilio::REST::Trigger.any_instance.unstub(:delete)
	end

	it 'should add usage daily threshold triggers when security unwhitelisted' do
		trigger = mock
		trigger.stubs(:sid).returns('TRIGR')
		trigger.stubs(:current_value).returns('0')
		trigger.stubs(:trigger_value).returns('100')
		Twilio::REST::Triggers.any_instance.stubs(:create).returns(trigger)
		@account.freshfone_account.update_column(:security_whitelist, true)
		Resque.inline = true
		put :undo_security_whitelist, { :account_id => @account.id, :name_prefix => 'fdadmin_', :path_prefix => nil,:format => 'json' }, :content_type => 'application/json'
		Resque.inline = false
		@account.freshfone_account.reload
		expect(@account.freshfone_account.security_whitelist).to be false
		@account.freshfone_account.freshfone_usage_triggers.reload
		expect(@account.freshfone_account.freshfone_usage_triggers.count).to eq(2)
		expect(json[:status]).to eq('success')
		Twilio::REST::Triggers.any_instance.unstub(:create)
	end

	it 'do not restore when freshfone account is active' do
		freshfone_account = @account.freshfone_account
		expect(freshfone_account.active?).to be true
		put :restore_freshfone_account, { :account_id => @account.id, :name_prefix => 'fdadmin_', :path_prefix => nil,:format => 'json' }, :content_type => 'application/json'
		expect(json[:status]).to eq('notice')
	end

	it 'should restore when freshfone_account is suspended' do
		freshfone_account = @account.freshfone_account
		freshfone_account.update_column(:state, Freshfone::Account::STATE_HASH[:suspended])
		account_mock = mock
		account_mock.stubs(:update)
		Twilio::REST::Accounts.any_instance.stubs(:get).returns(account_mock)
		put :restore_freshfone_account, { 
			:account_id => @account.id,
			:name_prefix => 'fdadmin_',
			:path_prefix => nil,
			:format => 'json' }, :content_type => 'application/json'
		expect(json[:status]).to eq('success')
		Twilio::REST::Accounts.any_instance.unstub(:get)
	end

	it 'should fetch the trigger levels of daily threshold from account' do
		freshfone_account = @account.freshfone_account
		triggers = { :first => 75, :second => 200 }
		freshfone_account.update_attributes!(:triggers => triggers)
		get :fetch_usage_triggers,{ 
			:account_id => @account.id,
			:name_prefix => 'fdadmin_',
			:path_prefix => nil,
			:format => 'json'}, :content_type => 'application/json'
		expect(json[:status]).to eq('success')
		expect(json[:triggers]).to eq(triggers)
	end

	it 'should not update triggers if the values are same as exising triggers' do
		freshfone_account = @account.freshfone_account
		freshfone_account.update_attributes!(:triggers => { :first => 75, :second => 200 })
		put :update_usage_triggers, { 
			:account_id => @account.id,
			:name_prefix => 'fdadmin_',
			:path_prefix => nil,
			:trigger_first => '75',
			:trigger_second => '200',
			:format => 'json' }, :content_type => 'application/json'
		expect(json[:status]).to eq('notice')
	end

	it 'should update triggers if trigger values are changed' do
		freshfone_account = @account.freshfone_account
		freshfone_account.update_attributes!(:triggers => { :first => 75, :second => 200 })
		trigger = mock
		trigger.stubs(:sid).returns('TRIGR')
		trigger.stubs(:current_value).returns('0')
		trigger.stubs(:trigger_value).returns('100')
		Twilio::REST::Triggers.any_instance.stubs(:create).returns(trigger)
		Twilio::REST::Trigger.any_instance.stubs(:delete)

		Resque.inline = true
		put :update_usage_triggers, { 
			:account_id => @account.id,
			:name_prefix => 'fdadmin_',
			:path_prefix => nil,
			:trigger_first => '100',
			:trigger_second => '200',
			:format => 'json' }, :content_type => 'application/json'
		Resque.inline = false
		expect(json[:status]).to eq('success')
		expect(freshfone_account.freshfone_usage_triggers.count).to eq(2)
		Twilio::REST::Triggers.any_instance.unstub(:create)
		Twilio::REST::Trigger.any_instance.unstub(:delete)
	end

	it 'should not update triggers if the account is suspended' do
		freshfone_account = @account.freshfone_account
		freshfone_account.update_column(:state, Freshfone::Account::STATE_HASH[:suspended])
		expect(freshfone_account.active?).to be false
		expect(freshfone_account.suspended?).to be true
		put :update_usage_triggers, { 
			:account_id => @account.id,
			:name_prefix => 'fdadmin_',
			:path_prefix => nil,
			:trigger_first => '100',
			:trigger_second => '200',
			:format => 'json' }, :content_type => 'application/json'
		expect(json[:status]).to eq('suspended')
	end

	it 'should not update triggers if the account is whitelisted' do
		freshfone_account = @account.freshfone_account
		freshfone_account.update_column(:security_whitelist, true)
		expect(freshfone_account.security_whitelist).to be true
		put :update_usage_triggers, { 
			:account_id => @account.id,
			:name_prefix => 'fdadmin_',
			:path_prefix => nil,
			:trigger_first => '100',
			:trigger_second => '200',
			:format => 'json' }, :content_type => 'application/json'
		expect(json[:status]).to eq('whitelisted')
	end
end

require 'spec_helper'
include EbayHelper
RSpec.describe Admin::Ecommerce::EbayController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@account.features.ecommerce.create
	end

	after(:all) do
		@account.ebay_accounts.delete_all
	end

	before(:each) do
		login_admin
	end

	it "should render new ebay account form" do
		get :new
		response.body.should =~ /Email/
    response.body.should =~ /Account Name/
    response.body.should =~ /Application ID/
    response.body.should =~ /Developer ID/
    response.body.should =~ /Auth Token/
    response.body.should =~ /Certificate ID/
    response.body.should =~ /RU Name/
    response.should be_success
	end

	it "should not render new page if it exceeds 5 ecommerce accounts" do
		@account.ebay_accounts.delete_all
		5.times do
			create_ebay_account
		end
		get :new
		response.should redirect_to("/admin/ecommerce/accounts")
		session[:flash][:notice].should eql(I18n.t('admin.ecommerce.limit_exceed'))
	end

	it "should create new ebay account" do
		@account.ebay_accounts.delete_all
		Resque.inline = true 
		before_count = @account.ebay_accounts.count
		params = {:ecommerce_ebay => get_ebay_configuration, :email_configuration => '0', 
			:email_config => {:name => Faker::Lorem.sentence(2), 
				:reply_email => Faker::Internet.email, :to_email => Faker::Internet.email, 
				:active => true, :account_id => @account.id }}
		post :create, params
		Resque.inline = false
		ebay_acc = @account.ebay_accounts.find_by_name(params[:ecommerce_ebay][:name])
		ebay_acc.name == params[:ecommerce_ebay][:name]
		session[:flash][:notice].should eql(I18n.t('admin.ecommerce.new.account_created'))
		response.should redirect_to("/admin/ecommerce/accounts")
		@account.ebay_accounts.count.should eql(before_count + 1)
		ebay_acc = @account.ebay_accounts.find_by_name(params[:ecommerce_ebay][:name])
		ebay_acc.email_config.should be_present
		ebay_acc.should be_an_instance_of(Ecommerce::Ebay)
	end

	it "should edit the ebay account" do
		@account.reload
		ebay_acc = @account.ebay_accounts.last
		get :edit, :id => ebay_acc.id
		response.body.should =~ /#{ebay_acc.name}/
		response.should be_success
	end

	it "should update an ebay account" do
		ebay_acc = @account.ebay_accounts.last
		name = Faker::Lorem.sentence(2)
		put :update, {:id => ebay_acc.id, :ecommerce_ebay => {:name => name}, :email_configuration => "1" }
		ebay_acc.reload
		ebay_acc.name.should eql(name)
		response.should redirect_to('/admin/ecommerce/accounts')
	end

	it "should destroy an ebay account" do
		ebay_acc = @account.ebay_accounts.last
		delete :destroy, :id => ebay_acc.id
		@account.ebay_accounts.find_by_id(ebay_acc.id).should be_nil
		response.should redirect_to('/admin/ecommerce/accounts')
	end

end
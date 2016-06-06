require 'spec_helper'

RSpec.describe Integrations::XeroController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    remove_marketplace_feature
    @user = add_test_agent(@account)
    @xero_installed_app = FactoryGirl.build(:installed_application,
        :application_id => Integrations::Application.find_by_name("xero").id,
        :account_id => @account.id,
        :configs => {
          :inputs => {
            "refresh_token" => "GF82COZHCJQ0ETKEO0ZL",
            "oauth_token" => "IQXG0CBTZTMZ9W9UT2DQ4F4ZH8UZCO",
            "oauth_secret" => "NUJUWHTB7TP60BLDBIUMO8HXKY1SIS",
            "accounts_code" => ["1", "2", "3"],
            "items_code" => ["1"],
            "default_desc" => "Freshdesk Ticket {{ticket.id}}",
            "expires_at" => "#{Time.now}"
          }
        }
      )
    @xero_installed_app.save!
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    @integrated_res = FactoryGirl.build(:integrated_resource, :installed_application_id => @xero_installed_app.id,
                    :remote_integratable_id => "1106038", :local_integratable_id => @test_ticket.id,
                    :local_integratable_type => "Helpdesk::Ticket", :account_id => @account.id)
    @integrated_res.save!
    @new_user = FactoryGirl.build(:user, :avatar_attributes => { :content => fixture_file_upload('files/image4kb.png', 
                                        'image/png')},
                                    :name => "Test user Xero",
                                    :email => Faker::Internet.email,
                                    :time_zone => "Chennai",
                                    :delta => 1,
                                    :deleted => 0,
                                    :blocked => 0,
                                    :customer_id => nil,
                                    :language => "en")
    @new_user.save
  end

  before(:each) do
    log_in(@user)
    access_token_hash = {:token => "token", :secret => "secret"}
    access_token = OpenStruct.new access_token_hash
    Xeroizer::PartnerApplication.any_instance.stubs(:access_token).returns(access_token)
    Xeroizer::PartnerApplication.any_instance.stubs(:session_handle).returns("session_handle")
    Xeroizer::OAuth.any_instance.stubs(:instance_variable_get).with(:@expires_at).returns(Time.now)
    Xeroizer::PartnerApplication.any_instance.stubs(:authorize_from_access).returns("access_token")
    Xeroizer::PartnerApplication.any_instance.stubs(:renew_access_token).returns("access_token")
  end

  it "should authorize the the xero client" do
    hash = {:token => "token", :secret => "secret", :authorize_url => "authorize_url"}
    request_token = OpenStruct.new hash
    Xeroizer::PartnerApplication.any_instance.stubs(:request_token).returns(request_token)
    get :authorize, {:controller => "integrations/xero", :action => "authorize"}
    response.should redirect_to "authorize_url"
  end

  it "should throw error if authorization is wrong" do 
    Xeroizer::PartnerApplication.any_instance.stubs(:request_token).returns(nil)
    get :authorize, {:controller => "integrations/xero", :action => "authorize"}
    flash[:notice].should eql "Error while installing the app."
    response.should redirect_to "/integrations/applications"
  end

  it "should redirect to the authdone" do
    get :install, {:controller => "integrations/xero", :action => "install", :redirect_url => "redirect_url", :oauth_verifier => "oauth_verifier"}
    response.should redirect_to "redirect_url#{integrations_xero_authdone_path}?oauth_verifier=oauth_verifier"
  end

  it "should fetch the fields and render the settings page" do
    organisation_hash = {:name => "name"}
    items_hash = {:item_id => "item_id", :description => "description"}
    accounts_hash = {:name => "name", :account_id => "account_id"}
    @request.session['xero_request_token'] = "xero_request_token"
    @request.session['xero_request_secret'] = "xero_request_secret"
    org_name, items, accounts = Array.new, Array.new, Array.new
    org_name << (OpenStruct.new organisation_hash)
    items << (OpenStruct.new items_hash)
    accounts << (OpenStruct.new accounts_hash)
    Xeroizer::PartnerApplication.any_instance.stubs(:authorize_from_request).returns(nil)
    Xeroizer::PartnerApplication.any_instance.stubs(:Organisation).returns(org_name)
    Xeroizer::Record::ItemModel.any_instance.stubs(:all).returns(items)
    Xeroizer::Record::AccountModel.any_instance.stubs(:all).returns(accounts)
    get :authdone, {:controller => "integrations/xero", :action => "authdone"}
    response.should render_template("integrations/applications/xero_fields")
  end

  it "should render the settings page for edit" do
    organisation_hash = {:name => "name"}
    items_hash = {:item_id => "item_id", :description => "description"}
    accounts_hash = {:name => "name", :account_id => "account_id"}
    org_name, items, accounts = Array.new, Array.new, Array.new
    org_name << (OpenStruct.new organisation_hash)
    items << (OpenStruct.new items_hash)
    accounts << (OpenStruct.new accounts_hash)
    Xeroizer::PartnerApplication.any_instance.stubs(:Organisation).returns(org_name)
    Xeroizer::Record::ItemModel.any_instance.stubs(:all).returns(items)
    Xeroizer::Record::AccountModel.any_instance.stubs(:all).returns(accounts)
    get :edit, {:controller => "integrations/xero", :action => "edit"}
    response.should render_template("integrations/applications/xero_fields")
  end

  it "should update the installed applications" do
    get :update_params, {:controller => "integrations/xero", :action => "update_params", 
               :accounts => ["1", "2"], :items => ["1"], :description => "Freshdesk ticket {{ticket.id}}"}
    response.should redirect_to "/integrations/applications"
  end

  it "should fetch all the invoices when contact is present" do
    contacts_hash = {:contact_id => "contact_id"}
    contacts = Array.new
    contacts << (OpenStruct.new contacts_hash)
    Xeroizer::Record::ContactModel.any_instance.stubs(:all).returns(contacts)
    Xeroizer::Record::InvoiceModel.any_instance.stubs(:all).returns(nil)
    get :fetch, {:controller => "integrations/xero", :action => "fetch", :ticket_id => "1", :reqCompanyName => "CompanyName"}
    response.status.should eql 200
  end

  it "should return the exact invoice" do 
    items_hash = {:item_code=>"item_code"} 
    items = Array.new
    items.push(OpenStruct.new items_hash)
    line_items_hash = {:line_items =>  items}
    invoice = OpenStruct.new line_items_hash
    Xeroizer::Record::InvoiceModel.any_instance.stubs(:find).returns(invoice)
    item_hash = {:description => "description"}
    item = OpenStruct.new item_hash
    Xeroizer::Record::ItemModel.any_instance.stubs(:find).returns(item)
    get :get_invoice, {:controller => "integrations/xero", :action => "get_invoice"}
    response.status.should eql 200
  end

  it "should fetch the contact if exists" do
    contacts_hash = {:contact_id => "contact_id"}
    contacts = Array.new
    contacts << (OpenStruct.new contacts_hash)
    Xeroizer::Record::ContactModel.any_instance.stubs(:all).returns(contacts)
    # Xeroizer::Record::InvoiceModel.any_instance.stubs(:all).returns(nil)
    get :fetch_create_contacts, {:controller => "integrations/xero", :action => "fetch_create_contacts", :ticket_id => "1", :reqCompanyName => "CompanyName"}
    response.status.should eql 200
  end

  it "should create a new contact if no contact exists" do
    Xeroizer::Record::ContactModel.new("contact","new")
    contact = Xeroizer::Record::Contact.new(@application)
    Xeroizer::Record::ContactModel.any_instance.stubs(:all).returns(nil)
    Xeroizer::Record::ContactModel.any_instance.stubs(:build).returns(contact)
    Xeroizer::Record::Contact.any_instance.stubs(:save).returns(nil)
    Xeroizer::Record::Contact.any_instance.stubs(:contact_id).returns(nil)
    get :fetch_create_contacts, {:controller => "integrations/xero", :action => "fetch_create_contacts", :ticket_id => "1", :reqCompanyName => "CompanyName", :reqEmail => "Email"}
    response.status.should eql 200
  end

  it "should return the accounts" do
    accounts_hash = {:name => "name", :account_id => "account_id", :code => "code"}
    accounts = Array.new
    accounts << (OpenStruct.new accounts_hash)
    Xeroizer::Record::AccountModel.any_instance.stubs(:all).returns(accounts)
    get :render_accounts, {:controller => "integrations/xero", :action => "render_accounts"}
    response.status.should eql 200
  end

  it "should fetch the currency when params is present" do
    Xeroizer::Record::CurrencyModel.any_instance.stubs(:find).returns("currency")
    get :render_currency, {:controller => "integrations/xero", :action => "render_currency", :code => "code"}
    response.status.should eql 200
  end

  it "should fetch the currency when params is not present" do
    Xeroizer::Record::CurrencyModel.any_instance.stubs(:all).returns("currency")
    get :render_currency, {:controller => "integrations/xero", :action => "render_currency"}
    response.status.should eql 200
  end

  it "should return the items" do
    items_hash = {:item_id => "item_id", :code => "code", :description => "description"}
    accounts_hash = {:name => "name", :account_id => "account_id"}
    items, accounts = Array.new, Array.new
    items << (OpenStruct.new items_hash)
    accounts << (OpenStruct.new accounts_hash)
    Xeroizer::Record::ItemModel.any_instance.stubs(:all).returns(items)
    Xeroizer::Record::AccountModel.any_instance.stubs(:all).returns(accounts)
    get :check_item_exists, {:controller => "integrations/xero", :action => "check_item_exists"}
    response.status.should eql 200
  end

  it "should create a new invoice with line_item" do
    Xeroizer::Record::InvoiceModel.new("invoice","new")
    invoice = Xeroizer::Record::Invoice.new(@application)
    line_items ={:key1 => {:item_code => "item_code", :description => "description", :time_spent => "time_spent", :account_code => "account_code", :unit_amount => "unit_amount"}}
    tax_type = {:tax_type => "tax_type"}
    sales_details = OpenStruct.new tax_type
    items_hash = {:item_id => "item_id", :description => "description", :sales_details => sales_details}
    items = Array.new
    items << (OpenStruct.new items_hash)
    Xeroizer::Record::ItemModel.any_instance.stubs(:all).returns(items)
    Xeroizer::Record::InvoiceModel.any_instance.stubs(:find).returns(invoice)
    Xeroizer::Record::Invoice.any_instance.stubs(:add_line_item).returns("success")
    Xeroizer::Record::Invoice.any_instance.stubs(:save).returns("success")
    post :create_invoices, {:contacts => "integrations/xero", :action => "create_invoices", :invoice_id => "invoice_id", :line_items => line_items.to_json}
    response.status.should eql 200
  end

  it "should create a new invoice without line_item" do
    Xeroizer::Record::InvoiceModel.new("invoice","new")
    invoice = Xeroizer::Record::Invoice.new(@application)
    Xeroizer::Record::ContactModel.new("contact","new")
    contact = Xeroizer::Record::Contact.new(@application)
    line_items ={:key1 => {:description => "description", :time_spent => "time_spent", :account_code => "account_code", :unit_amount => "unit_amount"}}
    Xeroizer::Record::InvoiceModel.any_instance.stubs(:build).returns(invoice)
    Xeroizer::Record::ContactModel.any_instance.stubs(:find).returns(contact)
    Xeroizer::Record::Invoice.any_instance.stubs(:add_line_item).returns("success")
    Xeroizer::Record::Invoice.any_instance.stubs(:save).returns("success")
    post :create_invoices, {:contacts => "integrations/xero", :action => "create_invoices", :contact_id => "contact_id", :line_items => line_items.to_json, :current_date => "#{Time.now}"}
    response.status.should eql 200
  end
end

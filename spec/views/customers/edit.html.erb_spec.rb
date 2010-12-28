require 'spec_helper'

describe "/customers/edit.html.erb" do
  include CustomersHelper

  before(:each) do
    assigns[:customer] = @customer = stub_model(Customer,
      :new_record? => false,
      :name => "value for name",
      :cust_identifier => "value for cust_identifier",
      :owner_id => 1,
      :account_id => 1,
      :cust_type => 1,
      :phone => "value for phone",
      :address => "value for address",
      :website => "value for website",
      :description => "value for description"
    )
  end

  it "renders the edit customer form" do
    render

    response.should have_tag("form[action=#{customer_path(@customer)}][method=post]") do
      with_tag('input#customer_name[name=?]', "customer[name]")
      with_tag('input#customer_cust_identifier[name=?]', "customer[cust_identifier]")
      with_tag('input#customer_owner_id[name=?]', "customer[owner_id]")
      with_tag('input#customer_account_id[name=?]', "customer[account_id]")
      with_tag('input#customer_cust_type[name=?]', "customer[cust_type]")
      with_tag('input#customer_phone[name=?]', "customer[phone]")
      with_tag('input#customer_address[name=?]', "customer[address]")
      with_tag('input#customer_website[name=?]', "customer[website]")
      with_tag('textarea#customer_description[name=?]', "customer[description]")
    end
  end
end

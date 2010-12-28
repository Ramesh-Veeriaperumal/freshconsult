require 'spec_helper'

describe "/customers/index.html.erb" do
  include CustomersHelper

  before(:each) do
    assigns[:customers] = [
      stub_model(Customer,
        :name => "value for name",
        :cust_identifier => "value for cust_identifier",
        :owner_id => 1,
        :account_id => 1,
        :cust_type => 1,
        :phone => "value for phone",
        :address => "value for address",
        :website => "value for website",
        :description => "value for description"
      ),
      stub_model(Customer,
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
    ]
  end

  it "renders a list of customers" do
    render
    response.should have_tag("tr>td", "value for name".to_s, 2)
    response.should have_tag("tr>td", "value for cust_identifier".to_s, 2)
    response.should have_tag("tr>td", 1.to_s, 2)
    response.should have_tag("tr>td", 1.to_s, 2)
    response.should have_tag("tr>td", 1.to_s, 2)
    response.should have_tag("tr>td", "value for phone".to_s, 2)
    response.should have_tag("tr>td", "value for address".to_s, 2)
    response.should have_tag("tr>td", "value for website".to_s, 2)
    response.should have_tag("tr>td", "value for description".to_s, 2)
  end
end

require 'spec_helper'

describe "/customers/show.html.erb" do
  include CustomersHelper
  before(:each) do
    assigns[:customer] = @customer = stub_model(Customer,
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

  it "renders attributes in <p>" do
    render
    response.should have_text(/value\ for\ name/)
    response.should have_text(/value\ for\ cust_identifier/)
    response.should have_text(/1/)
    response.should have_text(/1/)
    response.should have_text(/1/)
    response.should have_text(/value\ for\ phone/)
    response.should have_text(/value\ for\ address/)
    response.should have_text(/value\ for\ website/)
    response.should have_text(/value\ for\ description/)
  end
end

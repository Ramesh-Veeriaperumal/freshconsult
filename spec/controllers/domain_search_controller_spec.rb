require 'spec_helper'

describe DomainSearchController do
  it "should list all the domains associated with an email" do
    get :locate_domain, :user_email => @account.admin_email
    JSON.parse(response.body)["available"].should be_eql(true)
  end

  it "should ensure that the email sent is not blank" do
    get :locate_domain
    JSON.parse(response.body)["available"].should be_eql(false)
  end
end
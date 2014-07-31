require 'spec_helper'

describe AccountConfigurationsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_name = Faker::Name.name
  end

  before(:each) do
    login_admin
  end

  it "should update the account configuration" do
    email = RSpec.configuration.account.account_configuration.contact_info[:email]
    put :update, {
      :account_configuration=>{ :contact_info=>{:first_name=> @test_name, :last_name=> @test_name, 
                                                :email=> email, :phone=>"23888880"},
                                :billing_emails=>{:invoice_emails=>["#{email}"]}
                              }
    }
    RSpec.configuration.account.reload
    session[:flash][:notice].should eql "Account settings updated successfully!"
    RSpec.configuration.account.account_configuration.contact_info[:first_name].should eql "#{@test_name}"
    RSpec.configuration.account.account_configuration.contact_info[:phone].should eql "23888880"
  end

  it "should not update the account configuration without emailID" do
    put :update, {
      :account_configuration=>{ :contact_info=>{:first_name=> "Lee", :last_name=> "MinHo", 
                                                :email=> "", :phone=>"23881880"},
                                :billing_emails=>{:invoice_emails=>""}
                              }
    }
    RSpec.configuration.account.reload
    session[:flash][:notice].should eql "Failed to update Account Settings!"
    RSpec.configuration.account.account_configuration.contact_info[:last_name].should_not eql "MinHo"
    RSpec.configuration.account.account_configuration.contact_info[:phone].should_not eql "23881880"
    RSpec.configuration.account.account_configuration.contact_info[:first_name].should eql "#{@test_name}"
  end
end
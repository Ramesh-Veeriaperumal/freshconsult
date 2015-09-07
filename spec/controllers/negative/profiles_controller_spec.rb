require 'spec_helper'

describe ProfilesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    log_in(@agent)
  end

  after(:all) do
    Delayed::Job.destroy_all
  end

  it "should not send security email when mobile and phone number changes from null to empty string" do
  	put :update, :id => @agent.id,
      :agent =>{ :signature_html=>"<p><br></p>\r\n",
        :user_id => "#{@agent.id}" },
        :user =>{ :name => "#{@agent.name}",
        :job_title => "",
        :phone => "",
        :mobile => "",
        :time_zone => "Chennai",
        :language => "en"
      }
    Delayed::Job.last.handler.should_not include("Your Phone number and Mobile number in #{@account.name} has been updated") if Delayed::Job.last

  end

end

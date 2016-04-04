require 'spec_helper'

describe AgentsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @role_id = ["#{@account.roles.first.id}"]
  end

  it "should not allow a limited access agent to create a new agent" do
    restricted_agent = add_agent(@account, { :name => Faker::Name.name,
                                            :email => Faker::Internet.email,
                                            :active => 1,
                                            :role => 1,
                                            :agent => 1,
                                            :ticket_permission => 1,
                                            :role_ids => ["#{@account.roles.find_by_name("Agent").id}"] })
    log_in(restricted_agent)
    test_email = Faker::Internet.email
    post :create, { :agent => { :occasional => "false",
                                :scoreboard_level_id => "1",
                                :signature_html=> "Cheers!",
                                :user_id => "",
                                :ticket_permission => "1"
                                },
                    :user => { :helpdesk_agent => "true",
                                :name => Faker::Name.name,
                                :email => test_email,
                                :time_zone => "Chennai",
                                :job_title =>"Technical Support",
                                :phone => Faker::PhoneNumber.phone_number,
                                :language => "en",
                                :role_ids => ["#{@account.roles.first.id}"],
                                :roleValidate => ""
                              }
                  }
    @account.user_emails.user_for_email(test_email).should be_nil
  end

  it "should not allow the admin to create more agents than allowed by the plan" do
    login_admin
    @account.subscription.update_attributes(:state => "active", :agent_limit => @account.full_time_agents.count)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    test_email = Faker::Internet.email
    post :create, { :agent => { :occasional => "false",
                                :scoreboard_level_id => "1",
                                :signature_html=> "Cheers!",
                                :user_id => "",
                                :ticket_permission => "1"
                                },
                    :user => { :helpdesk_agent => "true",
                                :name => Faker::Name.name,
                                :email => test_email,
                                :time_zone => "Chennai",
                                :job_title =>"Technical Support",
                                :phone => Faker::PhoneNumber.phone_number,
                                :language => "en",
                                :role_ids => ["#{@account.roles.first.id}"],
                                :roleValidate => ""
                              }
                  }
    @account.user_emails.user_for_email(test_email).should be_nil
    @account.subscription.update_attributes(:state => "trial")
  end
end

require 'spec_helper'
include IntegrationsHelper
include TicketHelper
include UsersHelper
include NoteHelper

describe Integrations::Slack::SlackUtil do
  self.use_transactional_fixtures = false

  before(:all) do
    @ticket = create_ticket
    @ticket.update_attributes(description: nil)
    @user = add_test_agent(@account)
    @app_name = "slack"
    @ticket.account.installed_applications.with_name('slack').destroy_all

    @input_options = {:inputs => {'refresh_token' => "", 
                                  'oauth_token' => " xoxp-2896389166-2896389170-3232451622-4f4ec4",
                                   'channels' =>[{"channel_id"=>"C032CAS5X", "actions"=>"Note creation,Status update,Ticket creation"}]
                                }
                    }

    @installed_application = create_installed_applications({ :configs => @input_options, :account_id => @account.id, :application_name => @app_name})
  end
 
  it "should post to slack on ticket create" do
    obj = Integrations::Slack::SlackUtil.new()
    tkt_data = {:name=>"Integrations::Slack::SlackUtil", :value=>"post_to_slack_on_ticket_create", :action=>"Ticket creation"}
    response = obj.post_to_slack_on_ticket_create(@ticket, tkt_data)
    response.should_not be_nil
  end

  it "should post to slack on ticket update" do
    @ticket.update_attributes(status: 3)
    obj = Integrations::Slack::SlackUtil.new()
     tkt_data = {:name=>"Integrations::Slack::SlackUtil", :value=>"post_to_slack_on_ticket_update", :action=>"Status update"}
     response = obj.post_to_slack_on_ticket_update(@ticket, tkt_data)
     response.should_not be_nil
  end

  it "should post to slack on note create" do
    obj = Integrations::Slack::SlackUtil.new()
    tkt_data = {:name=>"Integrations::Slack::SlackUtil", :value=>"post_to_slack_on_note_create", :action=>"Note creation"}
    note = create_note({:source => @ticket.source, :ticket_id => @ticket.id, :user_id => @user.id})
    response = obj.post_to_slack_on_note_create(note, tkt_data)
    response.should_not be_nil
  end
end
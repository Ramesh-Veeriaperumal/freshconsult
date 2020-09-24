require 'spec_helper'
load 'spec/support/freshfone_spec_helper.rb'
include FreshfoneSpecHelper

RSpec.describe Freshfone::TicketActions do
  self.use_transactional_fixtures = false
  
  include Freshfone::TicketActions
  before(:all) do
    @agent = get_admin
  end

  before(:each) do
    create_test_freshfone_account
    @account.freshfone_callers.delete_all
  end
  
  it 'create a new voicemail ticket' do
    freshfone_call = create_freshfone_call
    build_freshfone_caller
    params = { :CallSid => freshfone_call.call_sid, :call_log => "Sample Freshfone Voicemail Ticket", 
               :ticket_subject => "Call with Arya Stark", :call_history => "false",
               :name => "Arya Stark", :email => "arya@northwinterfell.com", :voicemail => true }
    set_current_call(freshfone_call)
    voicmail_ticket(params)
    current_call.ticket.subject.should be_eql("Voicemail from +12345678900")
  end

end
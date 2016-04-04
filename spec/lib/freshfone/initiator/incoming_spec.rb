require 'spec_helper'
RSpec.configure do |c|
  c.include ConferenceTransferSpecHelper
  c.include Freshfone::CallValidator
  c.include Freshfone::FreshfoneUtil
  c.include Freshfone::Endpoints
  c.include Freshfone::AgentsLoader
end


RSpec.describe Freshfone::Initiator::Incoming do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @account.freshfone_calls.destroy_all
    @account.freshfone_callers.delete_all
    create_freshfone_conf_call('CONFCALL')
    @incoming = Freshfone::Initiator::Incoming.new({:call=>@freshfone_call.id,:From => @agent.user_id},@account,@number)
  end

  it "should process regular_incoming call successfully" do 
  	result = @incoming.regular_incoming
  	expect(result).to match(/Response/)
  	expect(result).to match(/Say/)
  end

end


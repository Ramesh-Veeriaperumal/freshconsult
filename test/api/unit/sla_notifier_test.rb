require_relative '../unit_test_helper'
class SLANotifierTest < ActiveSupport::TestCase
  def trigger_escalation_test
    begin
      account = Account.first
      ticket = account.tickets.first
      user = account.users.first
      params = { subject: 'test subject', email_body: 'test email body' }
      SlaNotifier.trigger_escalation ticket, user, 13, params
    rescue => e
      return false
    end
    true
  end
end

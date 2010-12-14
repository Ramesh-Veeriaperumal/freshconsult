require 'test_helper'

class SlaNotifierTest < ActionMailer::TestCase
  test "sla_escalation" do
    @expected.subject = 'SlaNotifier#sla_escalation'
    @expected.body    = read_fixture('sla_escalation')
    @expected.date    = Time.now

    assert_equal @expected.encoded, SlaNotifier.create_sla_escalation(@expected.date).encoded
  end

end

require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module SocialHelper
  
  def create_test_ticket_rule(stream, account=nil)
    account = stream.account if account.nil?
    account.make_current
    @ticket_rule = Factory.build(:ticket_rule, :account_id => account.id, :stream_id => stream.id)
    @ticket_rule.save
    @ticket_rule
  end

end

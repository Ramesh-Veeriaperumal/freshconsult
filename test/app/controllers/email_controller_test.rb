require_relative '../../api/test_helper'
class EmailControllerTest < ActionController::TestCase
  def test_redirect_email_triggered_in_validate_domain
    params = { domain: 'localhost.freshpo.com', username: 'freshpo' }
    @controller.params = params
    @controller.expects(:redirect_email).once
    DomainMapping.new
    DomainMapping.stubs(:find_by_domain).returns(DomainMapping.first)
    ShardMapping.stubs(:lookup_with_domain).returns(ShardMapping.new(account_id: 1, shard_name: 'shard_1', status: 200, pod_info: 'ap-south-1'))
    Account.new
    Account.stubs(:find_by_full_domain).returns(Account.first)
    @controller.stubs(:ok?).returns(true)
    @controller.stubs(:render).returns(true)
    @controller.send(:validate_domain)
  end

  def test_redirect_email_not_triggered_in_validate_domain
    params = { domain: 'localhost.freshpo.com', username: 'freshpo' }
    @controller.params = params
    @controller.expects(:redirect_email).never
    DomainMapping.new
    DomainMapping.stubs(:find_by_domain).returns(DomainMapping.first)
    ShardMapping.new
    ShardMapping.stubs(:lookup_with_domain).returns(ShardMapping.first)
    Account.new
    Account.stubs(:find_by_full_domain).returns(Account.first)
    @controller.stubs(:ok?).returns(true)
    @controller.stubs(:render).returns(true)
    @controller.send(:validate_domain)
  end
end

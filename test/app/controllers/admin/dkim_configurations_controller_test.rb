require_relative '../../../api/test_helper'
class Admin::DkimConfigurationsControllerTest < ActionController::TestCase
  include EmailMailboxTestHelper

  def test_show_domains_with_verified_email_configs
    @verified_email_config = create_email_config(support_email: 'test@freshpo.com')
    @verified_email_config.active = true
    @verified_email_config.save
    @unverified_email_config = create_email_config(active: false, support_email: 'test@test2.com')
    active_domains = @account.outgoing_email_domain_categories.first
    active_domains.status = 2
    active_domains.save!
    get :index
    assert_response 200
    assert_equal true, response.body.include?('freshpo.com')
    assert_equal false, response.body.include?('fd.com')
  ensure
    @verified_email_config.destroy
    @unverified_email_config.destroy
  end
end

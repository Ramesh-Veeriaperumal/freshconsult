require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class PortalTest < ActiveSupport::TestCase
  include AccountTestHelper

  def setup
    super
    create_test_account if @account.nil?
    @account.launch(:skip_portal_cname_chk)
  end

  def test_domain_mapping_trigger
    main_portal = @account.main_portal
    main_portal.portal_url = "demo.lorem#{Time.now.to_i}ipsum.com"
    main_portal.save!
    Fdadmin::APICalls.stubs(:non_global_pods?).returns(true)
    Fdadmin::APICalls.stubs(:connect_main_pod).returns(true)
    main_portal.reload
    main_portal.portal_url = nil
    PortalObserver.any_instance.expects(:remove_custom_domain_from_global).once
    main_portal.save!
  ensure
    Fdadmin::APICalls.unstub(:non_global_pods?)
    Fdadmin::APICalls.unstub(:connect_main_pod)
  end
end

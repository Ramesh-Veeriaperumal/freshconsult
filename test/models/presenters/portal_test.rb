require_relative '../test_helper'

class PortalTest < ActiveSupport::TestCase
  include ModelsSolutionsTestHelper
  include PortalTestHelper

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.launch(:portal_central_publish)
    @@before_all_run = true
  end

  def test_central_publish_with_launch_party_disabled
    @account.rollback(:portal_central_publish)
    CentralPublisher::Worker.jobs.clear
    create_portal
    assert_equal 0, CentralPublisher::Worker.jobs.size
  ensure
    @account.launch(:portal_central_publish)
  end

  def test_central_publish_with_launch_party_enabled
    CentralPublisher::Worker.jobs.clear
    create_portal
    assert_equal 1, CentralPublisher::Worker.jobs.size
  end

  def test_portal_create_with_central_publish
    test_portal = create_portal
    payload = test_portal.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_portal_pattern(test_portal))
  end

  def test_portal_update_central_publish_payload
    test_portal = create_portal
    old_name = test_portal.name
    CentralPublisher::Worker.jobs.clear
    update_portal(test_portal)
    assert_equal 1, CentralPublisher::Worker.jobs.size
    payload = test_portal.central_publish_payload.to_json    
    payload.must_match_json_expression(central_publish_portal_pattern(test_portal))
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'portal_update', job['args'][0]
    assert_equal(model_changes_for_central_pattern([old_name, test_portal.name]), job['args'][1]['model_changes'])
  end

  def test_response_destroy_central_publish
    test_portal = create_portal
    pattern_to_match = central_publish_portal_destroy_pattern(test_portal)
    CentralPublisher::Worker.jobs.clear
    test_portal.destroy
    assert_equal 1, CentralPublisher::Worker.jobs.size
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'portal_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(pattern_to_match)
  end
end
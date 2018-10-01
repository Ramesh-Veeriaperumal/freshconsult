require_relative '../test_helper'

class InstalledApplicationTest < ActiveSupport::TestCase
  include InstalledApplicationsTestHelper

  def test_central_publish_payload
    installed_app = Account.current.installed_applications.first
    payload = installed_app.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_installed_app_pattern(installed_app))
  end


end
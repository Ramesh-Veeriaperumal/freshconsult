require_relative '../test_helper'

class ApplicationsTest < ActiveSupport::TestCase
  include ApplicationsTestHelper

  def test_central_publish_payload
    app = Integrations::Application.first
    payload = app.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_app_pattern(app))
  end
end
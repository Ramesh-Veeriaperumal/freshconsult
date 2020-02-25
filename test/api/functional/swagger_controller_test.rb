require_relative '../test_helper'

class SwaggerControllerTest < ActionController::TestCase

  def test_respond_for_production_environment
    Rails.env.stubs(:production?).returns(true)
    get :respond, controller_params
    assert_response 404
    Rails.env.unstub(:production?)
  end

  def test_respond
    get :respond, controller_params.merge(format: 'html')
    assert_response 200
    response.body.include?('Freshdesk Private API documentation')
  end

  def test_respond_help_widget
    get :respond, controller_params.merge(path: 'help_widget/index.html', format: 'html')
    assert_response 200
    response.body.include?('Help Widget Public API documentation')
  end
end

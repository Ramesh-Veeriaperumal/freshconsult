require_relative '../../test_helper'
class Ember::InstalledApplicationsControllerTest < ActionController::TestCase
  include InstalledApplicationsTestHelper

  def setup
    super
    mkt_place = Account.current.features?(:marketplace)
    Account.current.features.marketplace.destroy if mkt_place
    Account.current.reload
  end

  def wrap_cname(params)
    { installed_applications: params }
  end

  def test_index
    create_application('zohocrm')
    get :index, controller_params(version: 'private')
    pattern = []
    Account.current.installed_applications.all.each do |app|
      pattern << installed_application_pattern(app)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_show_installed_app
    app = Account.current.installed_applications.first
    get :show, construct_params(version: 'private', id: app.id)
    assert_response 200
    match_json(installed_application_pattern(app))
  end

  def test_show_missing_app
    get :show, construct_params(version: 'private', id: 10_000_001)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_app_index_filter
    create_application('harvest')
    harvest_app = Account.current.installed_applications.find_by_application_id(3)
    pattern = []
    pattern << installed_application_pattern(harvest_app)
    get :index, controller_params({ version: 'private', name: 'harvest' }, {})
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_app_index_filter_with_multipe_names
    pattern = []
    harvest_app = Account.current.installed_applications.find_by_application_id(3)
    pattern << installed_application_pattern(harvest_app)
    get :index, controller_params({ version: 'private', name: 'harvest,zohocrm' }, {})
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_app_index_with_invalid_filter
    get :index, controller_params(version: 'private', abc: 'harvest')
    match_json([bad_request_error_pattern('abc', :invalid_field, code: :invalid_field, description: 'Validation failed')])
    assert_response 400
  end
end

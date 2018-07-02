require_relative '../../test_helper'
require Rails.root.join('spec', 'support', 'solutions_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'portals_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'portals_customisation_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'attachments_test_helper.rb')

class Ember::PortalsControllerTest < ActionController::TestCase
  include SolutionsHelper
  include PortalsTestHelper
  include AttachmentsTestHelper
  include PortalsCustomisationTestHelper
  include BotTestHelper
  include ProductsHelper

  def setup
    super
    before_all
   end

  def wrap_cname(params)
    { portal: params }
  end

  @before_all_run = false

  def before_all
    3.times do
      create_portal
    end
    @before_all_run = true
  end

  def test_index
    get :index, controller_params(version: 'private')
    pattern = []
    Account.current.portals.all.each do |portal|
      pattern << portal_pattern(portal)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_show
    portal = Account.current.portals.first
    get :show, controller_params(version: 'private', id: portal.id)
    assert_response 200
    match_json(portal_pattern(portal))
  end

  def test_show_with_invalid_portal_id
    get :show, controller_params(version: 'private', id: 0)
    assert_response 404
  end

  def test_show_without_access
    portal = Account.current.portals.first
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
    get :show, controller_params(version: 'private', id: portal.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    User.any_instance.unstub(:privilege?)
  end

  def test_show_with_invalid_field
    portal = Account.current.portals.first
    get :show, controller_params(version: 'private', id: portal.id, test: 'test')
    assert_response 400
    match_json([bad_request_error_pattern('test', :invalid_field)])
  end

  def test_show_with_incorrect_credentials
    @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
    portal = Account.current.portals.first
    get :show, controller_params(version: 'private', id: portal.id)
    assert_response 401
    assert_equal request_error_pattern(:credentials_required).to_json, response.body
    @controller.unstub(:api_current_user)
  end

  def test_update_colors
    portal = create_portal_with_customisation
    params_hash = portal_hash(portal)
    put :update, construct_params({ version: 'private', id: portal.id }, params_hash.merge(helpdesk_logo: nil))
    assert_response 200
    portal.reload
    match_json(portal_show_pattern(portal))
    assert portal.preferences[:helpdesk][:primary_background] == params_hash[:preferences][:helpdesk][:primary_background]
    assert portal.preferences[:helpdesk][:nav_background] == params_hash[:preferences][:helpdesk][:nav_background]
  end

  def test_update_logo
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
    portal = create_portal_with_customisation
    logo = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: Account.current.id)
    params_hash = portal_hash(portal)
    put :update, construct_params({ version: 'private', id: portal.id }, params_hash.merge(helpdesk_logo: logo.attributes))
    assert_response 200
    portal.reload
    match_json(portal_show_pattern(portal))
    assert portal.helpdesk_logo.id == logo.id
    assert portal.preferences[:helpdesk][:primary_background] == params_hash[:preferences][:helpdesk][:primary_background]
    assert portal.preferences[:helpdesk][:nav_background] == params_hash[:preferences][:helpdesk][:nav_background]
  end

  def test_update_reset_preference
    portal = create_portal_with_customisation
    params_hash = portal_hash(portal)
    params_hash = params_hash.merge(helpdesk_logo: nil)
    put :update, construct_params({ version: 'private', id: portal.id }, params_hash)
    assert_response 200
    portal.reload
    match_json(portal_show_pattern(portal))
  end

  def test_bot_prerequisites
    portal = Account.current.portals.first
    get :bot_prerequisites, controller_params(version: 'private', id: portal.id)
    assert_response 200
    Language.for_current_account.make_current
    match_json(bot_prerequisites_pattern(portal))
    Language.reset_current
  end

  def test_bot_prerequisites_with_invalid_portal_id
    get :bot_prerequisites, controller_params(version: 'private', id: 0)
    assert_response 404
  end

  def test_bot_prerequisites_without_access
    portal = Account.current.portals.first
    User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
    get :bot_prerequisites, controller_params(version: 'private', id: portal.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    User.any_instance.unstub(:privilege?)
  end

  def test_bot_prerequisites_with_invalid_field
    portal = Account.current.portals.first
    get :bot_prerequisites, controller_params(version: 'private', id: portal.id, test: 'test')
    assert_response 400
    match_json([bad_request_error_pattern('test', :invalid_field)])
  end

  def test_bot_prerequisites_with_incorrect_credentials
    @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
    portal = Account.current.portals.first
    get :bot_prerequisites, controller_params(version: 'private', id: portal.id)
    assert_response 401
    assert_equal request_error_pattern(:credentials_required).to_json, response.body
    @controller.unstub(:api_current_user)
  end

  def test_bot_prerequisites_for_portal_with_bot
    bot = create_bot(product: true)
    get :bot_prerequisites, controller_params(version: 'private', id: bot.portal_id)
    assert_response 400
    match_json([bad_request_error_pattern('id', :bot_exists, code: :invalid_value)])
  end
end

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
  include ApiBotTestHelper
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

  def test_show_for_portal_without_name
    product = create_product
    portal = create_portal(product_id: product.id)
    get :show, controller_params(version: 'private', id: portal.id)
    assert_response 200
    match_json(portal_pattern(portal))
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
  
  def test_update_colors_for_sprout
    Subscription.any_instance.stubs(:sprout_plan?).returns(true)
    portal = create_portal_with_customisation
    params_hash = portal_hash(portal)
    put :update, construct_params({ version: 'private', id: portal.id }, params_hash.merge(helpdesk_logo: nil))
    assert_response 403
    portal.reload
    Subscription.any_instance.unstub(:sprout_plan?)
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

  def test_update_logo_without_helpdesk_preferences
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
    portal = create_portal_with_customisation
    logo = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: Account.current.id)
    params_hash = portal_hash(portal)
    params_hash[:preferences].delete(:helpdesk)
    put :update, construct_params({ version: 'private', id: portal.id }, params_hash.merge(helpdesk_logo: logo.attributes))
    assert_response 200
    portal.reload
    assert portal.helpdesk_logo.id == logo.id
  end

  def test_update_helpdesk_preferences_without_logo
    portal = create_portal_with_customisation
    params_hash = portal_hash(portal)
    params_hash.delete(:helpdesk_logo)
    put :update, construct_params({ version: 'private', id: portal.id }, params_hash)
    assert_response 200
    portal.reload
    assert portal.preferences[:helpdesk][:primary_background] == params_hash[:preferences][:helpdesk][:primary_background]
    assert portal.preferences[:helpdesk][:nav_background] == params_hash[:preferences][:helpdesk][:nav_background]
  end

  def test_bot_prerequisites
    skip('failures and errors 21')
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

  def test_link_back_url_with_space
     # contains space in between
    check_portal_update_with_invalid_url('http://loremipsum.com/droid dmoe/')
  end

  def test_link_back_url_without_tld
    # doesn't have top level domain
    check_portal_update_with_invalid_url('http://loremipsum/droid dmoe/')
  end

  def test_link_back_url_with_invalid_length
    # more than 63 chars in host part
    check_portal_update_with_invalid_url('http://loremipsumloremipsumloremipsumloremipsumloremipsumloremipsumloremipsumloremipsumloremipsumloremipsum.com/droid/')
  end

  def test_link_back_url_with_invalid_tld
    # top level domain should contain atleast two chars
    check_portal_update_with_invalid_url('http://loremipsum.c')
  end

  def test_link_back_url_with_local_ip
    check_portal_update_with_invalid_url('https://192.168.0.1/maps/place/Nagalapuram,+Andhra+Pradesh+517589/@13.5252021,79.8047142,3a,75y,187.5h,90t/data=!3m8!1e1!3m6!1sAF1QipMRGXX6_2va0YsRo44Edo_67YIQ-Yq3NPpCDBnY!2e10!3e11!6shttps:%2F%2Flh5.googleusercontent.com%2Fp%2FAF1QipMRGXX6_2va0YsRo44Edo_67YIQ-Yq3NPpCDBnY%3Dw86-h86-k-no-pi-0-ya110.5-ro0-fo100!7i8704!8i4352!4m5!3m4!1s0x3a4d610798df206d:0x3a5f49a106d2ab7e!8m2!3d13.3857837!4d79.7988547')
  end

  def test_link_back_url_with_invalid_port
    check_portal_update_with_invalid_url('https://اف@#$@$%#$%غانستا.icom.mu:809033/coasmmc/com')
  end

  def test_link_back_url_with_underscore
    check_portal_update_with_valid_url('https://asdasd-o---asd.com/coasmmc/com/a?=a')
  end

  def test_link_back_url_with_tamil_language
    check_portal_update_with_valid_url('https://dmeo.இந்தியா/coasmmc/com')
  end

  def test_link_back_url_with_accented_chars
    check_portal_update_with_valid_url('https://ăâåč.icom.mu:8090/coasmmc/com')
  end

  def test_link_back_url_with_japanese
    check_portal_update_with_valid_url('https://JP納豆.例.jp/coasmmc/com')
  end

  def test_link_back_url_with_valid_url_and_path
    check_portal_update_with_valid_url('https://www.google.co.in/maps/place/Nagalapuram,+Andhra+Pradesh+517589/@13.5252021,79.8047142,3a,75y,187.5h,90t/data=!3m8!1e1!3m6!1sAF1QipMRGXX6_2va0YsRo44Edo_67YIQ-Yq3NPpCDBnY!2e10!3e11!6shttps:%2F%2Flh5.googleusercontent.com%2Fp%2FAF1QipMRGXX6_2va0YsRo44Edo_67YIQ-Yq3NPpCDBnY%3Dw86-h86-k-no-pi-0-ya110.5-ro0-fo100!7i8704!8i4352!4m5!3m4!1s0x3a4d610798df206d:0x3a5f49a106d2ab7e!8m2!3d13.3857837!4d79.7988547')
  end

  private
  def check_portal_update_with_valid_url(url)
    portal = create_portal_with_customisation
    params_hash = portal_hash(portal)
    params_hash[:preferences] = params_hash[:preferences].merge(logo_link: url)
    put :update, construct_params({ version: 'private', id: portal.id }, params_hash)
    assert_response 200
    portal.reload
    match_json(portal_show_pattern(portal))
  end

  def check_portal_update_with_invalid_url(url)
    portal = create_portal_with_customisation
    params_hash = portal_hash(portal)
    params_hash[:preferences] = params_hash[:preferences].merge(logo_link: url)
    put :update, construct_params({ version: 'private', id: portal.id }, params_hash)
    assert_response 400
    portal.reload
    assert portal[:preferences][:log_link] != url
  end
end

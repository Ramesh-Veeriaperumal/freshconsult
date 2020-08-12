require_relative '../../test_helper'
class Email::MailboxesControllerTest < ActionController::TestCase
  include Email::Mailbox::Constants
  include EmailMailboxTestHelper
  include GroupsTestHelper
  include ProductsHelper

  def setup
    super
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.any_instance.stubs(:multiple_emails_enabled?).returns(true)
    User.any_instance.stubs(:has_privilege?).with(:manage_email_settings).returns(true)
  end

  def teardown
    Account.any_instance.unstub(:multiple_emails_enabled?)
    User.any_instance.unstub(:has_privilege?)
    Account.unstub(:current)
    super
  end

  def wrap_cname(params)
    { mailbox: params }
  end

  def create_mailbox_params_hash
    {
      support_email: Faker::Internet.email,
      mailbox_type: FRESHDESK_MAILBOX
    }
  end

  def test_delete_secondary_email
    email_config = create_email_config(active: false, default_reply_email: false)
    delete :destroy, construct_params(id: email_config.id)
    assert_response 204
  end

  def test_cannot_delete_default_reply_email
    email_config = create_email_config(active: true, default_reply_email: true)
    delete :destroy, construct_params(id: email_config.id)
    assert_response 400
    match_json([bad_request_error_pattern('error', :cannot_delete_default_reply_email)])
  end

  def test_invalid_id
    delete :destroy, construct_params(id: Faker::Number.number(5))
    assert_response 404
  end

  # test create success
  # test_create_without_feature
  # test create without support mail
  # test create without mailbox_type
  # test_create_with_name
  # test_create_with_invalid_name_length
  # test create with group_id
  # test create with product_id
  # test_create_with_product_id_without_feature
  # test_create_with_invalid_product_id
  # test create with default_reply_email
  # test_create_with_incoming_custom_mailbox
  # test_create_with_outgoing_custom_mailbox
  # test_create_with_both_custom_mailbox
  # test_create_with_invalid_incoming_custom_mailbox
  # test create invalid custommailbox with freshdeskmailbox params

  def test_create_success
    params_hash = create_mailbox_params_hash
    post :create, construct_params({}, params_hash)
    assert_response 201
    match_json(mailbox_pattern({}, EmailConfig.last))
  end

  def test_create_without_feature
    Account.any_instance.stubs(:multiple_emails_enabled?).returns(false)
    params_hash = create_mailbox_params_hash
    post :create, construct_params({}, params_hash)
    assert_response 403
    request_error_pattern(:require_feature, feature: 'multiple_emails')
  ensure
    Account.any_instance.unstub(:multiple_emails_enabled?)
  end

  def test_create_without_support_email
    params_hash = create_mailbox_params_hash.except(:support_email)
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :support_email,
      :missing_field,
      code: :missing_field
    )])
  end

  def test_create_without_mailbox_type
    params_hash = create_mailbox_params_hash.except(:mailbox_type)
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :mailbox_type,
      :missing_field,
      code: :missing_field
    )])
  end

  def test_create_with_name
    params_hash = create_mailbox_params_hash.merge(name: Faker::Lorem.characters(150))
    post :create, construct_params({}, params_hash)
    assert_response 201
    match_json(mailbox_pattern({}, EmailConfig.last))
  end

  def test_create_with_invalid_name_length
    params_hash = create_mailbox_params_hash.merge(name: Faker::Lorem.characters(257))
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :name,
      :too_long,
      current_count: 257,
      element_type: 'characters',
      max_count: 255,
      code: :invalid_value
    )])
  end

  def test_create_with_group_id
    group = create_group(@account)
    params_hash = create_mailbox_params_hash.merge(group_id: group.id)
    post :create, construct_params({}, params_hash)
    assert_response 201
    match_json(mailbox_pattern({}, EmailConfig.last))
  end

  def test_create_with_product_id
    Account.any_instance.stubs(:multi_product_enabled?).returns(true)
    product = create_product
    params_hash = create_mailbox_params_hash.merge(product_id: product.id)
    post :create, construct_params({}, params_hash)
    assert_response 201
    match_json(mailbox_pattern({}, EmailConfig.last))
  ensure
    Account.any_instance.unstub(:multi_product_enabled?)
  end

  def test_create_with_product_id_without_feature
    Account.any_instance.stubs(:multi_product_enabled?).returns(false)
    product = create_product
    params_hash = create_mailbox_params_hash.merge(product_id: product.id)
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :product_id,
      :require_feature_for_attribute,
      attribute: 'product_id',
      feature: :multi_product,
      code: :invalid_value
    )])
  ensure
    Account.any_instance.unstub(:multi_product_enabled?)
  end

  def test_create_with_invalid_product_id
    Account.any_instance.stubs(:multi_product_enabled?).returns(true)
    params_hash = create_mailbox_params_hash.merge(product_id: 40_000)
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :product_id,
      :absent_in_db,
      resource: 'product',
      attribute: 'product_id',
      code: :invalid_value
    )])
  ensure
    Account.any_instance.unstub(:multi_product_enabled?)
  end

  def test_create_with_default_reply_email
    params_hash = create_mailbox_params_hash.merge(default_reply_email: true)
    post :create, construct_params({}, params_hash)
    assert_response 201
    match_json(mailbox_pattern({}, EmailConfig.last))
  end

  def test_create_with_incoming_custom_mailbox
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: true, msg: '')
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 201
    match_json(mailbox_pattern({}, EmailConfig.last))
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
  end

  def test_create_with_outgoing_custom_mailbox
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_smtp_mailbox).returns(success: true, msg: '')
    options = { access_type: 'outgoing' }
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 201
    match_json(mailbox_pattern({}, EmailConfig.last))
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_smtp_mailbox)
  end

  def test_create_with_both_custom_mailbox
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: true, msg: '')
    Email::MailboxDelegator.any_instance.stubs(:verify_smtp_mailbox).returns(success: true, msg: '')
    options = { access_type: 'both' }
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 201
    match_json(mailbox_pattern({}, EmailConfig.last))
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
    Email::MailboxDelegator.any_instance.unstub(:verify_smtp_mailbox)
  end

  def test_create_with_invalid_incoming_custom_mailbox
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: false, msg: 'Error while verifying the mailbox imap details. Please verify server name, port and credentials')
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :incoming,
      :'Error while verifying the mailbox imap details. Please verify server name, port and credentials',
      code: :invalid_value
    )])
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
  end

  def test_create_with_incoming_custom_mailbox_without_delete_from_server
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: true, msg: '')
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash).merge(mailbox_type: CUSTOM_MAILBOX)
    params_hash[:custom_mailbox][:incoming].delete(:delete_from_server)
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      :incoming,
      :delete_from_server,
      :'It should be a/an Boolean',
      code: :missing_field
    )])
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
  end

  def test_create_with_incoming_custom_mailbox_without_use_ssl
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: true, msg: '')
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash).merge(mailbox_type: CUSTOM_MAILBOX)
    params_hash[:custom_mailbox][:incoming].delete(:use_ssl)
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      :incoming,
      :use_ssl,
      :'It should be a/an Boolean',
      code: :missing_field
    )])
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
  end

  def test_create_with_outgoing_custom_mailbox_without_use_ssl
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: true, msg: '')
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(access_type: 'outgoing')).merge(mailbox_type: CUSTOM_MAILBOX)
    params_hash[:custom_mailbox][:outgoing].delete(:use_ssl)
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      :outgoing,
      :use_ssl,
      :'It should be a/an Boolean',
      code: :missing_field
    )])
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
  end

  # test update success
  # test_update_without_feature
  # test_update_support_email
  # test_update_default_reply_email
  # test_update_group_id
  # test_update_product_id
  # test_update_with_incoming_custom_mailbox
  # test_update_with_outgoing_custom_mailbox
  # test_update_freshdesk_to_custom_mailbox
  # test_update_custom_to_freshdesk_mailbox

  def test_update_success
    email_config = create_email_config
    params_hash = { name: 'updated name' }
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 200
    match_json(mailbox_pattern(params_hash, EmailConfig.find_by_id(email_config.id)))
  end

  def test_update_without_feature
    Account.any_instance.stubs(:multiple_emails_enabled?).returns(false)
    email_config = create_email_config
    params_hash = { name: 'updated name' }
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 200
    match_json(mailbox_pattern(params_hash, EmailConfig.find_by_id(email_config.id)))
  ensure
    Account.any_instance.unstub(:multiple_emails_enabled?)
  end

  def test_update_support_email
    email_config = create_email_config
    params_hash = { support_email: Faker::Internet.email.to_s }
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 200
    match_json(mailbox_pattern(params_hash, EmailConfig.find_by_id(email_config.id)))
  end

  def test_update_default_reply_email
    email_config = create_email_config
    params_hash = { default_reply_email: true }
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 200
    match_json(mailbox_pattern(params_hash, EmailConfig.find_by_id(email_config.id)))
  end

  def test_update_group_id
    email_config = create_email_config
    params_hash = { group_id: create_group(@account).id }
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 200
    match_json(mailbox_pattern(params_hash, EmailConfig.find_by_id(email_config.id)))
  end

  def test_update_product_id
    email_config = create_email_config
    Account.any_instance.stubs(:multi_product_enabled?).returns(true)
    params_hash = { product_id: create_product.id }
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 200
    match_json(mailbox_pattern(params_hash, EmailConfig.find_by_id(email_config.id)))
  ensure
    Account.any_instance.unstub(:multi_product_enabled?)
  end

  def test_update_with_incoming_custom_mailbox
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: true, msg: '')
    Email::MailboxDelegator.any_instance.stubs(:verify_smtp_mailbox).returns(success: true, msg: '')
    email_config = create_email_config(imap_mailbox_attributes: { imap_server_name: 'imap.gmail.com' })
    params_hash = create_custom_mailbox_hash(access_type: 'outgoing')
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 200
    match_json(mailbox_pattern({}, EmailConfig.find_by_id(email_config.id)))
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
    Email::MailboxDelegator.any_instance.unstub(:verify_smtp_mailbox)
  end

  def test_update_with_outgoing_custom_mailbox
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: true, msg: '')
    email_config = create_email_config(smtp_mailbox_attributes: { smtp_server_name: 'smtp.gmail.com' })
    params_hash = create_custom_mailbox_hash(access_type: 'incoming')
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 200
    match_json(mailbox_pattern({}, EmailConfig.find_by_id(email_config.id)))
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
  end

  def test_update_freshdesk_to_custom_mailbox
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: true, msg: '')
    Email::MailboxDelegator.any_instance.stubs(:verify_smtp_mailbox).returns(success: true, msg: '')
    email_config = create_email_config
    params_hash = create_custom_mailbox_hash(access_type: 'both').merge(mailbox_type: CUSTOM_MAILBOX)
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 200
    match_json(mailbox_pattern({}, EmailConfig.find_by_id(email_config.id)))
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
    Email::MailboxDelegator.any_instance.unstub(:verify_smtp_mailbox)
  end

  def test_update_custom_to_freshdesk_mailbox
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: true, msg: '')
    email_config = create_email_config(
      imap_mailbox_attributes: { imap_server_name: 'imap.gmail.com' },
      smtp_mailbox_attributes: { smtp_server_name: 'smtp.gmail.com' }
    )
    params_hash = { name: 'updated name', mailbox_type: 'freshdesk_mailbox' }
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 200
    match_json(mailbox_pattern({}, EmailConfig.find_by_id(email_config.id)))
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
  end

  def test_update_product_id_on_default_mailbox
    email_config = EmailConfig.find_by_primary_role(true)
    email_config = create_email_config(primary_role: true) if email_config.blank?
    Account.any_instance.stubs(:multi_product_enabled?).returns(true)
    params_hash = { product_id: create_product.id }
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :product_id,
      :default_mailbox_product_changed,
      code: :invalid_value
    )])
  ensure
    Account.any_instance.unstub(:multi_product_enabled?)
  end

  def test_update_plain_to_oauth_mailbox
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: true, msg: '')
    email_config = create_email_config(
      imap_mailbox_attributes: { imap_server_name: 'imap.gmail.com' },
      smtp_mailbox_attributes: { smtp_server_name: 'smtp.gmail.com' }
    )
    Email::MailboxValidation.any_instance.stubs(:private_api?).returns(true)
    Email::MailboxesController.any_instance.stubs(:private_api?).returns(true)
    redis_key = 'GMAIL::test:xyz'
    value = {
      oauth_token: 'ya29.Il-vB0K5x3',
      support_email: 'testactivefilter@fd.com',
      refresh_token: 'xugvqw377',
      type: 'new',
      oauth_email: 'test@gmail.com'
    }
    $redis_others.perform_redis_op('mapped_hmset', redis_key, value)
    options = {
      support_email: 'testactivefilter@fd.com',
      imap_authentication: 'xoauth2',
      smtp_authentication: 'xoauth2',
      imap_user_name: 'test@gmail.com',
      smtp_user_name: 'test@gmail.com',
      imap_password: '',
      smtp_password: '',
      reference_key: redis_key,
      access_type: 'both'
    }
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 200
    match_json(mailbox_pattern({}, EmailConfig.find_by_id(email_config.id)))
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
    Email::MailboxValidation.any_instance.unstub(:private_api?)
    Email::MailboxesController.any_instance.unstub(:private_api?)
    $redis_others.perform_redis_op('del', redis_key)
  end

  def test_update_oauth_mailbox_to_different_account
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: true, msg: '')
    email_config = create_email_config(
      support_email: 'test@test3.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2',
        with_refresh_token: true,
        with_access_token: true
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2',
        with_refresh_token: true,
        with_access_token: true
      }
    )
    Email::MailboxValidation.any_instance.stubs(:private_api?).returns(true)
    Email::MailboxesController.any_instance.stubs(:private_api?).returns(true)
    redis_key = 'GMAIL::test:xyz'
    value = {
      oauth_token: 'ya29.Il-vB0K5x3',
      support_email: 'testactivefilter@fd.com',
      refresh_token: 'xugvqw377',
      type: 'new',
      oauth_email: 'test@gmail.com'
    }
    $redis_others.perform_redis_op('mapped_hmset', redis_key, value)
    options = {
      support_email: 'testactivefilter@fd.com',
      imap_authentication: 'xoauth2',
      smtp_authentication: 'xoauth2',
      imap_user_name: 'test@gmail.com',
      smtp_user_name: 'test@gmail.com',
      imap_password: '',
      smtp_password: '',
      reference_key: redis_key,
      access_type: 'both'
    }
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :update, construct_params({ id: email_config.id }, params_hash)
    assert_response 200
    match_json(mailbox_pattern({}, EmailConfig.find_by_id(email_config.id)))
    assert_equal email_config.reload.smtp_mailbox.access_token, 'ya29.Il-vB0K5x3'
    access_token_key = format(
      OAUTH_ACCESS_TOKEN_VALIDITY,
      provider: 'google_oauth2',
      account_id: Account.current.id,
      smtp_mailbox_id: email_config.smtp_mailbox.id
    )
    assert_equal $redis_others.perform_redis_op('exists', access_token_key), true
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
    Email::MailboxValidation.any_instance.unstub(:private_api?)
    Email::MailboxesController.any_instance.unstub(:private_api?)
    $redis_others.perform_redis_op('del', redis_key)
    $redis_others.perform_redis_op('del', access_token_key)
  end

  # test_send_verification_success
  # test_send_verification_on_active_mailbox

  def test_send_verification
    email_config = create_email_config(active: false)
    post :send_verification, construct_params(id: email_config.id)
    assert_response 204
  end

  def test_send_verification_on_active_mailbox
    email_config = create_email_config
    email_config.active = true
    email_config.save
    post :send_verification, construct_params(id: email_config.id)
    assert_response 409
    match_json(request_error_pattern(:active_mailbox_verification))
  end

  # _success
  # _success_with_order_type

  def _success
    user = add_new_user(@account)
    email_configs = []
    3.times do
      email_configs << create_email_config(active: false, default_reply_email: false)
    end
    per_page = 1
    Email::MailboxFilterValidation.any_instance.stubs(:private_api?).returns(true)
    get :index, controller_params(version: 'private', per_page: per_page)

    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/_/email/mailboxes?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(version: 'private', per_page: per_page, page: EmailConfig.count)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  ensure
    Email::MailboxFilterValidation.any_instance.unstub(:private_api?)
  end

  def _success_with_order_type
    user = add_new_user(@account)
    email_configs = []
    email_configs << create_email_config(active: false, default_reply_email: false, group_id: 5)
    email_configs << create_email_config(active: false, default_reply_email: false, group_id: 2)
    email_configs << create_email_config(active: false, default_reply_email: false, group_id: 1)
    per_page = 2
    Email::MailboxFilterValidation.any_instance.stubs(:private_api?).returns(true)
    get :index, controller_params(version: 'private', per_page: per_page, order_by: 'group_id', order_type: 'desc')
    assert_response 200
    assert JSON.parse(response.body).count == per_page

    parsed_response = JSON.parse(response.body)
    if parsed_response[0]['default_reply_email'] == false || (parsed_response[0]['default_reply_email'] == true && parsed_response[1]['default_reply_email'] == true) && (parsed_response[0]['group_id'].present? && parsed_response[1]['group_id'].present?)
      assert parsed_response[0]['group_id'] > parsed_response[1]['group_id']
    end
  ensure
    Email::MailboxFilterValidation.any_instance.unstub(:private_api?)
  end

  def test_list_with_support_email_filter_private
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    mailbox = create_email_config(support_email: 'testsupport@fd.com')
    Email::MailboxFilterValidation.any_instance.stubs(:private_api?).returns(true)
    get :index, controller_params(support_email: '*testsupport*', version: 'private')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  ensure
    Account.any_instance.unstub(:has_features?)
    @account.email_configs.destroy(mailbox)
    Email::MailboxFilterValidation.any_instance.unstub(:private_api?)
  end

  def test_list_failure_with_partial_support_email_v2
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    mailbox = create_email_config(support_email: 'testsupport@fd.com')
    Email::MailboxFilterValidation.any_instance.stubs(:private_api?).returns(false)
    get :index, controller_params(support_email: '*testsupport*', version: 'v2')
    assert_response 400
    parsed_response = JSON.parse(response.body)
    assert parsed_response['errors'][0]['message'].eql?('It should be in the \'valid email address\' format')
  ensure
    Account.any_instance.unstub(:has_features?)
    @account.email_configs.destroy(mailbox)
    Email::MailboxFilterValidation.any_instance.unstub(:private_api?)
  end

  def test_list_with_forward_email_filter
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    mailbox = create_email_config(forward_email: 'testforward@fd.com')
    get :index, controller_params(forward_email: 'testforward@fd.com')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  ensure
    Account.any_instance.unstub(:has_features?)
    @account.email_configs.destroy(mailbox)
    Email::MailboxFilterValidation.any_instance.unstub(:private_api?)
  end

  def test_list_with_product_id_filter
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    mailbox = create_email_config(support_email: 'testprodid@fd.com', product_id: 1)
    Email::MailboxFilterValidation.any_instance.stubs(:private_api?).returns(true)
    get :index, controller_params(support_email: 'testprodid@fd.com', product_id: 1)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  ensure
    Account.any_instance.unstub(:has_features?)
    @account.email_configs.destroy(mailbox)
    Email::MailboxFilterValidation.any_instance.unstub(:private_api?)
  end

  def test_list_with_group_id_filter
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    mailbox = create_email_config(support_email: 'testgroupid@fd.com', group_id: 1)
    Email::MailboxFilterValidation.any_instance.stubs(:private_api?).returns(true)
    get :index, controller_params(support_email: 'testgroupid@fd.com', group_id: 1)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  ensure
    Account.any_instance.unstub(:has_features?)
    @account.email_configs.destroy(mailbox)
    Email::MailboxFilterValidation.any_instance.unstub(:private_api?)
  end

  def test_list_with_active_filter
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    mailbox = create_email_config(support_email: 'testactivefilter@fd.com')
    mailbox.active = true
    mailbox.save!
    Email::MailboxFilterValidation.any_instance.stubs(:private_api?).returns(true)
    get :index, controller_params(support_email: 'testactivefilter@fd.com', active: true)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  ensure
    Account.any_instance.unstub(:has_features?)
    @account.email_configs.destroy(mailbox)
    Email::MailboxFilterValidation.any_instance.unstub(:private_api?)
  end

  def test_list_with_failure_code_filter
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    @account.all_email_configs.delete_all
    mailbox1 = create_email_config(support_email: 'testafailurecodefilter1@fd.com', default_reply_email: true, imap_mailbox_attributes: { imap_server_name: 'imap.gmail.com' })
    mailbox2 = create_email_config(support_email: 'testafailurecodefilter2@fd.com', imap_mailbox_attributes: { imap_server_name: 'imap.gmail.com' })
    mailbox3 = create_email_config(support_email: 'testafailurecodefilter3@fd.com', default_reply_email: true, imap_mailbox_attributes: { imap_server_name: 'imap.gmail.com' })
    mailbox4 = create_email_config(support_email: 'testafailurecodefilter4@fd.com', smtp_mailbox_attributes: { smtp_server_name: 'smtp.gmail.com' })
    mailbox1.active = true
    mailbox1.imap_mailbox.error_type = 543
    mailbox1.save!
    mailbox2.active = true
    mailbox2.imap_mailbox.error_type = 541
    mailbox2.save!
    mailbox4.smtp_mailbox.error_type = 535
    mailbox4.save!
    Email::MailboxFilterValidation.any_instance.stubs(:private_api?).returns(true)
    get :index, controller_params(order_by: 'failure_code')
    assert_response 200
    response = parse_response @response.body
    first_error_email = response[0]
    second_error_email = response[1]
    third_error_email = response[2]
    normal_email = response[3]
    assert_not_nil first_error_email['custom_mailbox']['incoming']['failure_code']
    assert_not_nil second_error_email['custom_mailbox']['outgoing']['failure_code']
    assert_not_nil third_error_email['custom_mailbox']['incoming']['failure_code']
    assert_equal true, normal_email['id'] == mailbox3.id
  ensure
    Account.any_instance.unstub(:has_features?)
    @account.email_configs.destroy(mailbox1)
    @account.email_configs.destroy(mailbox2)
    @account.email_configs.destroy(mailbox3)
    @account.email_configs.destroy(mailbox4)
    Email::MailboxFilterValidation.any_instance.unstub(:private_api?)
  end

  def test_oauth_imap_params
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxValidation.any_instance.stubs(:private_api?).returns(true)
    Email::MailboxesController.any_instance.stubs(:private_api?).returns(true)
    redis_key = 'GMAIL::test:xyz'
    value = {
      oauth_token: 'ya29.Il-vB0K5x3',
      support_email: 'testactivefilter12@fd.com',
      refresh_token: 'xugvqw377',
      type: 'new',
      oauth_email: 'test@gmail.com'
    }
    $redis_others.perform_redis_op('mapped_hmset', redis_key, value)
    options = {
      support_email: 'testactivefilter12@fd.com',
      imap_authentication: 'xoauth2',
      smtp_authentication: 'xoauth2',
      imap_user_name: 'test@gmail.com',
      smtp_user_name: 'test@gmail.com',
      imap_password: '',
      smtp_password: '',
      reference_key: redis_key,
      access_type: 'both'
    }
    Rails.env.stubs(:test?).returns(false)
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 201
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxValidation.any_instance.unstub(:private_api?)
    Email::MailboxesController.any_instance.unstub(:private_api?)
    Rails.env.unstub(:test?)
    $redis_others.perform_redis_op('del', redis_key)
  end

  def test_invalid_password_for_non_oauth
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxValidation.any_instance.stubs(:private_api?).returns(true)
    Email::MailboxesController.any_instance.stubs(:private_api?).returns(true)
    options = {
      support_email: 'testinvalidauth@fd.com',
      imap_authentication: 'plain',
      imap_password: ''
    }
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      :incoming,
      :password,
      :'Mandatory attribute missing',
      code: :missing_field
    )])
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxValidation.any_instance.unstub(:private_api?)
    Email::MailboxesController.any_instance.unstub(:private_api?)
  end

  def test_oauth_for_public_api
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxValidation.any_instance.stubs(:private_api?).returns(false)
    Email::MailboxesController.any_instance.stubs(:private_api?).returns(false)
    options = {
      support_email: 'testactivefilter@fd.com',
      imap_authentication: 'plain',
      smtp_authentication: 'plain',
      imap_password: '764768',
      reference_key: 'hffhyugewg',
      access_type: 'both'
    }
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 400
    parsed_response = JSON.parse(response.body)
    assert parsed_response['errors'][0]['field'].eql?('reference_key')
    assert parsed_response['errors'][0]['message'].eql?('Unexpected/invalid field in request')
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxValidation.any_instance.unstub(:private_api?)
    Email::MailboxesController.any_instance.unstub(:private_api?)
  end

  def test_oauth_for_private_api
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxValidation.any_instance.stubs(:private_api?).returns(true)
    Email::MailboxesController.any_instance.stubs(:private_api?).returns(true)
    redis_key = 'GMAIL::test:xyz'
    value = {
      oauth_token: 'ya29.Il-vB0K5x3',
      support_email: 'testactivefilter@fd.com',
      refresh_token: 'xugvqw377',
      type: 'new',
      oauth_email: 'test@gmail.com'
    }
    $redis_others.perform_redis_op('mapped_hmset', redis_key, value)
    options = {
      support_email: 'testactivefilter@fd.com',
      imap_authentication: 'xoauth2',
      smtp_authentication: 'xoauth2',
      imap_user_name: 'test@gmail.com',
      smtp_user_name: 'test@gmail.com',
      imap_password: '',
      smtp_password: '',
      reference_key: redis_key,
      access_type: 'both'
    }
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 201
    access_token_key = format(
      OAUTH_ACCESS_TOKEN_VALIDITY,
      provider: 'google_oauth2',
      account_id: Account.current.id,
      smtp_mailbox_id: Account.current.smtp_mailboxes.last.id
    )
    assert_equal $redis_others.perform_redis_op('exists', access_token_key), true
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxValidation.any_instance.unstub(:private_api?)
    Email::MailboxesController.any_instance.unstub(:private_api?)
    $redis_others.perform_redis_op('del', redis_key)
    $redis_others.perform_redis_op('del', access_token_key)
  end

  def test_incoming_mailbox_oauth_for_private_api
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxValidation.any_instance.stubs(:private_api?).returns(true)
    Email::MailboxesController.any_instance.stubs(:private_api?).returns(true)
    redis_key = 'GMAIL::test:xyz'
    value = {
      oauth_token: 'ya29.Il-vB0K5x3',
      support_email: 'testactivefilter@fd.com',
      refresh_token: 'xugvqw377',
      type: 'new',
      oauth_email: 'test@gmail.com'
    }
    $redis_others.perform_redis_op('mapped_hmset', redis_key, value)
    options = {
      support_email: 'testactivefilter@fd.com',
      imap_authentication: 'xoauth2',
      imap_user_name: 'test@gmail.com',
      imap_password: '',
      reference_key: redis_key,
      access_type: 'incoming'
    }
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 201
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxValidation.any_instance.unstub(:private_api?)
    Email::MailboxesController.any_instance.unstub(:private_api?)
    $redis_others.perform_redis_op('del', redis_key)
  end

  def test_outgoing_mailbox_oauth_for_private_api
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxValidation.any_instance.stubs(:private_api?).returns(true)
    Email::MailboxesController.any_instance.stubs(:private_api?).returns(true)
    redis_key = 'GMAIL::test:xyz'
    value = {
      oauth_token: 'ya29.Il-vB0K5x3',
      support_email: 'testactivefilter@fd.com',
      refresh_token: 'xugvqw377',
      type: 'new',
      oauth_email: 'test@gmail.com'
    }
    $redis_others.perform_redis_op('mapped_hmset', redis_key, value)
    options = {
      support_email: 'testactivefilter@fd.com',
      smtp_authentication: 'xoauth2',
      smtp_user_name: 'test@gmail.com',
      smtp_password: '',
      reference_key: redis_key,
      access_type: 'outgoing'
    }
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 201
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxValidation.any_instance.unstub(:private_api?)
    Email::MailboxesController.any_instance.unstub(:private_api?)
    $redis_others.perform_redis_op('del', redis_key)
  end

  def test_oauth_with_invalid_reference
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxValidation.any_instance.stubs(:private_api?).returns(true)
    Email::MailboxesController.any_instance.stubs(:private_api?).returns(true)
    redis_key = 'GMAIL::test:xyz'
    value = {
      oauth_token: 'ya29.Il-vB0K5x3',
      support_email: 'testactivefilter@fd.com',
      refresh_token: 'xugvqw377',
      type: 'new',
      oauth_email: 'test@gmail.com'
    }
    $redis_others.perform_redis_op('mapped_hmset', redis_key, value)
    options = {
      support_email: 'testactivefilter@fd.com',
      imap_authentication: 'xoauth2',
      smtp_authentication: 'xoauth2',
      imap_user_name: 'test@gmail.com',
      smtp_user_name: 'test@gmail.com',
      imap_password: '',
      smtp_password: '',
      reference_key: 'GMAIL::invalid::key',
      access_type: 'both'
    }
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :reference_key,
      :'OAuth reference is invalid. Please retry oauth process',
      code: :invalid_value
    )])
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxValidation.any_instance.unstub(:private_api?)
    Email::MailboxesController.any_instance.unstub(:private_api?)
    $redis_others.perform_redis_op('del', redis_key)
  end

  def test_oauth_without_refernce_key
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxValidation.any_instance.stubs(:private_api?).returns(true)
    Email::MailboxesController.any_instance.stubs(:private_api?).returns(true)
    redis_key = 'GMAIL::test:xyz'
    value = {
      oauth_token: 'ya29.Il-vB0K5x3',
      support_email: 'testactivefilter@fd.com',
      refresh_token: 'xugvqw377',
      type: 'new',
      oauth_email: 'test@gmail.com'
    }
    $redis_others.perform_redis_op('mapped_hmset', redis_key, value)
    options = {
      support_email: 'testactivefilter@fd.com',
      imap_authentication: 'xoauth2',
      smtp_authentication: 'xoauth2',
      imap_user_name: 'invalidemail@gmail.com',
      smtp_user_name: 'invalidemail@gmail.com',
      imap_password: '',
      smtp_password: '',
      access_type: 'both'
    }
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :reference_key,
      :'Mandatory attribute missing',
      code: :missing_field
    )])
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxValidation.any_instance.unstub(:private_api?)
    Email::MailboxesController.any_instance.unstub(:private_api?)
    $redis_others.perform_redis_op('del', redis_key)
  end

  def test_oauth_with_invalid_oauth_email
    Account.any_instance.stubs(:has_features?).with(:mailbox).returns(true)
    Email::MailboxValidation.any_instance.stubs(:private_api?).returns(true)
    Email::MailboxesController.any_instance.stubs(:private_api?).returns(true)
    redis_key = 'GMAIL::test:xyz'
    value = {
      oauth_token: 'ya29.Il-vB0K5x3',
      support_email: 'testactivefilter@fd.com',
      refresh_token: 'xugvqw377',
      type: 'new',
      oauth_email: 'test@gmail.com'
    }
    $redis_others.perform_redis_op('mapped_hmset', redis_key, value)
    options = {
      support_email: 'testactivefilter@fd.com',
      imap_authentication: 'xoauth2',
      smtp_authentication: 'xoauth2',
      imap_user_name: 'invalidemail@gmail.com',
      smtp_user_name: 'invalidemail@gmail.com',
      imap_password: '',
      smtp_password: '',
      reference_key: redis_key,
      access_type: 'both'
    }
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash(options)).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :reference_key,
      :'OAuth reference is invalid. Please retry oauth process',
      code: :invalid_value
    )])
  ensure
    Account.any_instance.unstub(:has_features?)
    Email::MailboxValidation.any_instance.unstub(:private_api?)
    Email::MailboxesController.any_instance.unstub(:private_api?)
    $redis_others.perform_redis_op('del', redis_key)
  end

  def test_successful_send_verification_email
    email_config = create_email_config(active: false)
    post :send_verification, construct_params(id: email_config.id)
    assert_response 204
  end
end

require_relative '../../test_helper'
class Email::MailboxesControllerTest < ActionController::TestCase
  include Email::Mailbox::Constants
  include EmailMailboxTestHelper
  include GroupsTestHelper
  include ProductsHelper

  def setup
    super
    Account.any_instance.stubs(:multiple_emails_enabled?).returns(true)
    User.any_instance.stubs(:has_privilege?).with(:manage_email_settings).returns(true)
  end

  def teardown
    Account.any_instance.unstub(:multiple_emails_enabled?)
    User.any_instance.unstub(:has_privilege?)
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
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
  end
  
   # test_index_success
  # test_index_success_with_order_type

  def test_index_success
    user = add_new_user(@account)
    email_configs = []
    3.times do
      email_configs << create_email_config(active: false, default_reply_email: false)
    end
    per_page = 1
    get :index, controller_params(version: 'private', per_page: per_page)

    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/_/email/mailboxes?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(version: 'private', per_page: per_page, page: EmailConfig.count)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def test_index_success_with_order_type
    user = add_new_user(@account)
    email_configs = []
    email_configs << create_email_config(active: false, default_reply_email: false, group_id: 5)
    email_configs << create_email_config(active: false, default_reply_email: false, group_id: 2)
    email_configs << create_email_config(active: false, default_reply_email: false, group_id: 1)
    per_page = 2

    get :index, controller_params(version: 'private', per_page: per_page, order_by: 'group_id', order_type: 'desc')
    assert_response 200
    assert JSON.parse(response.body).count == per_page

    parsed_response = JSON.parse(response.body)
    if parsed_response[0]['default_reply_email'] == false || (parsed_response[0]['default_reply_email'] == true && parsed_response[1]['default_reply_email'] == true) && (parsed_response[0]['group_id'].present? && parsed_response[1]['group_id'].present?)
      assert parsed_response[0]['group_id'] > parsed_response[1]['group_id']
    end
  end
end

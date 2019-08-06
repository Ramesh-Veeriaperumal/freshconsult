require_relative '../../test_helper'
class Email::MailboxesControllerTest < ActionController::TestCase
  include Email::Mailbox::Constants
  include EmailMailboxTestHelper
  include GroupsTestHelper
  include ProductsHelper

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
  # test create without support mail
  # test create without mailbox_type
  # test create without name
  # test create with group_id
  # test create with product_id
  # test create with default_reply_email
  # test create success with custom_mailbox
  # test create invalid custommailbox with freshdeskmailbox params

  def test_create_success
    params_hash = create_mailbox_params_hash
    post :create, construct_params({}, params_hash)
    p "response :: #{response.inspect}" # check random failure 403 repsonse
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
    Account.any_instance.stubs(:has_features?).returns(true)
    Email::MailboxDelegator.any_instance.stubs(:verify_imap_mailbox).returns(success: true, msg: '')
    params_hash = create_mailbox_params_hash.merge(create_custom_mailbox_hash).merge(mailbox_type: CUSTOM_MAILBOX)
    post :create, construct_params({}, params_hash)
    assert_response 201
    match_json(mailbox_pattern({}, EmailConfig.last))
    Account.any_instance.unstub(:has_features?)
    Email::MailboxDelegator.any_instance.unstub(:verify_imap_mailbox)
  end

  def test_create_with_outgoing_custom_mailbox
    Account.any_instance.stubs(:has_features?).returns(true)
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
    Account.any_instance.stubs(:has_features?).returns(true)
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
    Account.any_instance.stubs(:has_features?).returns(true)
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
end

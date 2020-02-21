require_relative '../unit_test_helper'

class AttachmentValidationTest < ActionView::TestCase

  PAID_PLANS = ["Blossom", "Garden", "Estate", "Forest"].freeze

  def self.fixture_path
    File.join(Rails.root, 'test/api/fixtures/')
  end

  def setup
    account = Account.new
    account.build_subscription
    Account.stubs(:current).returns(account)
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
  end

  def teardown
    Account.unstub(:current)
    ShardMapping.unstub(:fetch_by_domain)
    super
  end

  def test_numericality
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    controller_params = { 'user_id' => 1, content: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    assert attachment_validation.valid?(:create)

    controller_params = { 'user_id' => 'ABC', content: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('User datatype_mismatch')
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_content
    controller_params = { 'user_id' => 1, content: 'ABC' }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Content datatype_mismatch')

    controller_params = { 'user_id' => 1, content: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    FileSizeValidator.any_instance.stubs(:current_size).returns(26.megabytes)
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    FileSizeValidator.any_instance.unstub(:current_size)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Content invalid_size')

    controller_params = { 'user_id' => 1, content: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    assert attachment_validation.valid?(:create)
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_incompatible_fields
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    controller_params = { 'user_id' => 1, content: fixture_file_upload('files/image33kb.jpg', 'image/jpg'), inline: true, 'inline_type' => 1 }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('User cannot_set_user_id')

    controller_params = { 'user_id' => 1, content: fixture_file_upload('files/image33kb.jpg', 'image/jpg'), 'inline_type' => 5 }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Inline type cannot_set_inline_type')

    controller_params = { content: fixture_file_upload('files/image33kb.jpg', 'image/jpg'), inline: true }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Inline type missing_field')
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_invalid_inline_file_type
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    controller_params = { content: fixture_file_upload('files/attachment.txt', 'plain/text'), inline: true, 'inline_type' => 1 }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Content invalid_image_file')

    controller_params = { content: fixture_file_upload('files/image33kb.jpg', 'image/jpg'), inline: 'true', 'inline_type' => 100 }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Inline type not_included')
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_inline_image_upload
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)

    controller_params = { content: fixture_file_upload('files/image33kb.jpg', 'image/jpg'), inline: 'true', 'inline_type' => 2 }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    assert attachment_validation.valid?(:create)

    controller_params = { content: fixture_file_upload('files/plainfile', 'image/jpg'), inline: 'true', 'inline_type' => 2 }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    assert attachment_validation.valid?(:create)

    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_valid_unlink
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    controller_params = { 'attachable_id' => 1, 'attachable_type' => 'ticket' }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    assert attachment_validation.valid?(:unlink)
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_invalid_unlink
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    controller_params = {}
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:unlink)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Attachable missing_field')
    assert errors.include?('Attachable type missing_field')

    controller_params = { 'attachable_id' => -1, 'attachable_type' => 100 }
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:unlink)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Attachable datatype_mismatch')
    assert errors.include?('Attachable type not_included')
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_attachment_size_for_trial
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    assert_equal Account.current.attachment_limit, 20
    assert_attachment_limit(26, 19)
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_attachment_size_for_sprout
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Subscription.any_instance.stubs(:subscription_plan_from_cache).returns(SubscriptionPlan.new(:name => "Sprout Jan 17"))
    account = Account.current
    account.subscription.state = "free"
    account.subscription.subscription_plan = SubscriptionPlan.find_by_name("Sprout Jan 17")
    account.instance_variable_set("@attachment_limit", nil)
    assert_equal account.attachment_limit, 20
    assert_attachment_limit(22, 19)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    Subscription.any_instance.unstub(:subscription_plan_from_cache)
  end

  PAID_PLANS.each do |plan_name|
    define_method "test_attachment_size_for_#{plan_name}_with_25_launch_feature" do 
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      Subscription.any_instance.stubs(:subscription_plan_from_cache).returns(SubscriptionPlan.new(:name => "#{plan_name} Jan 17"))
      account = Account.current
      account.subscription.state = "active"
      account.subscription.subscription_plan = SubscriptionPlan.find_by_name(plan_name)
      account.launch(:outgoing_attachment_limit_25)
      account.instance_variable_set("@attachment_limit", nil)
      assert_equal account.attachment_limit, 25
      assert_attachment_limit(28, 23)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      Subscription.any_instance.unstub(:subscription_plan_from_cache)
      account.rollback(:outgoing_attachment_limit_25)
    end

    define_method "test_attachment_size_for_#{plan_name}_without_25_launch_feature" do 
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      Subscription.any_instance.stubs(:subscription_plan_from_cache).returns(SubscriptionPlan.new(:name => "#{plan_name} Jan 17"))
      account = Account.current
      account.subscription.state = "active"
      account.subscription.subscription_plan = SubscriptionPlan.find_by_name(plan_name)
      account.instance_variable_set("@attachment_limit", nil)
      assert_equal account.attachment_limit, 20
      assert_attachment_limit(23, 18)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      Subscription.any_instance.unstub(:subscription_plan_from_cache)
    end
  end

  def assert_attachment_limit(refute_val, assert_val)
    controller_params = { 'user_id' => 1, content: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) }
    FileSizeValidator.any_instance.stubs(:current_size).returns(refute_val.megabytes)
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    refute attachment_validation.valid?(:create)
    FileSizeValidator.any_instance.unstub(:current_size)
    errors = attachment_validation.errors.full_messages
    assert errors.include?('Content invalid_size')

    controller_params = { 'user_id' => 1, content: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) }
    FileSizeValidator.any_instance.stubs(:current_size).returns(assert_val.megabytes)
    attachment_validation = AttachmentValidation.new(controller_params, nil)
    assert attachment_validation.valid?(:create)
    FileSizeValidator.any_instance.unstub(:current_size)
    Account.current.instance_variable_set("@attachment_limit", nil)
  end
end

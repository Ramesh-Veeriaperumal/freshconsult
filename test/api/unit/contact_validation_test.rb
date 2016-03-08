require_relative '../unit_test_helper'

class ContactValidationTest < ActionView::TestCase
  def tear_down
    Account.unstub(:current)
    Account.any_instance.unstub(:contact_form)
    ContactForm.unstub(:default_contact_fields)
    super
  end

  def test_tags_comma_invalid
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = { 'name' => 'test', :email => Faker::Internet.email, tags: ['comma,test'] }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Tag names special_chars_present')
    assert_equal({ email: {}, tag_names: { chars: ',' }, name: {} }, contact.error_options)
  end

  def test_tags_comma_valid
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = { 'name' => 'test', :email => Faker::Internet.email, tags: ['comma', 'test'] }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    assert contact.valid?
  end

  def test_tags_multiple_errors
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = { 'name' => 'test', :email => Faker::Internet.email, tags: 'comma,test' }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Tag names data_type_mismatch')
    assert_equal({ email: {}, tag_names: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: String }, name: {} }, contact.error_options)
    assert errors.count == 1
  end

  def test_avatar_multiple_errors
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    String.any_instance.stubs(:size).returns(20_000_000)
    controller_params = { 'name' => 'test', :email => Faker::Internet.email, avatar: 'file.png' }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Avatar data_type_mismatch')
    assert_equal({ email: {}, name: {}, avatar: { expected_data_type: 'valid file format', prepend_msg: :input_received, given_data_type: String } }, contact.error_options)
    assert errors.count == 1
  end

  def test_complex_fields_with_nil
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = { 'name' => 'test', :email => Faker::Internet.email, tags: nil, custom_fields: nil }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Tag names data_type_mismatch')
    assert errors.include?('Custom fields data_type_mismatch')
    assert_equal({ email: {}, tag_names: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null Type' }, name: {}, custom_fields: { expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: 'Null Type' } }, contact.error_options)
    Account.unstub(:current)
  end

  def test_update_contact_with_fb_profile_id
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = { 'name' => 'test', :fb_profile_id => Faker::Internet.email }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    assert contact.valid?(:update)
    Account.unstub(:current)
  end

  def test_update_contact_without_contact_detail
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = { 'name' => 'test' }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    refute contact.valid?(:update)
    errors = contact.errors.full_messages
    assert errors.include?('Email fill_a_mandatory_field')
    assert_equal({ name: {}, email: { field_names: 'email, mobile, phone, twitter_id' } }, contact.error_options)
    Account.unstub(:current)
  end
end

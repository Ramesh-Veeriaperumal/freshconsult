require_relative '../unit_test_helper'

class ContactValidationTest < ActionView::TestCase

  def self.fixture_path
    File.join(Rails.root, 'test/api/fixtures/')
  end

  def teardown
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
    assert errors.include?('Tags special_chars_present')
    assert_equal({ email: {}, tags: { chars: ',' }, name: {} }, contact.error_options)
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

  def test_quick_create_with_company_valid
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      action: :quick_create,
      company_name: Faker::Lorem.characters(200)
    }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    assert contact.valid?
  end

  def test_quick_create_with_company_length_invalid
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      action: :quick_create,
      company_name: Faker::Lorem.characters(300)
    }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    refute contact.valid?
  end

  def test_quick_create_with_company_invalid
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      action: :quick_create,
      company_name: 1
    }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    refute contact.valid?
  end

  def test_quick_create_without_skip_company
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      company_id: 1
    }
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
    assert errors.include?('Tags datatype_mismatch')
    assert_equal({ email: {}, tags: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: String }, name: {} }, contact.error_options)
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
    assert errors.include?('Avatar datatype_mismatch')
    assert_equal({ email: {}, name: {}, avatar: { expected_data_type: 'valid file format', prepend_msg: :input_received, given_data_type: String } }, contact.error_options)
    assert errors.count == 1
    String.any_instance.unstub(:size)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    controller_params = { 'name' => 'test', :email => Faker::Internet.email, avatar: fixture_file_upload('files/attachment.txt', 'plain/text', :binary), avatar_id: 10 }
    contact = ContactValidation.new(controller_params, item)
    refute contact.valid?
    DataTypeValidator.any_instance.unstub(:valid_type?)
    errors = contact.errors.full_messages
    assert errors.include?('Avatar upload_jpg_or_png_file')
    assert errors.include?('Avatar only_avatar_or_avatar_id')
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
    assert errors.include?('Tags datatype_mismatch')
    assert errors.include?('Custom fields datatype_mismatch')
    assert_equal({ email: {}, tags: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null' }, name: {}, custom_fields: { expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: 'Null' } }, contact.error_options)
    Account.unstub(:current)
  end

  def test_complex_fields_with_invalid_datatype
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:custom_non_dropdown_fields).returns([contact_field('cf_custom_text')])
    controller_params = { 'name' => 'test', 'custom_fields' => { 'cf_custom_text' => 123 } }
    contact = ContactValidation.new(controller_params, nil)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Cf custom text datatype_mismatch')
    Account.unstub(:current)
  end

  def test_complex_fields_with_valid_datatype
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    ContactForm.any_instance.stubs(:custom_non_dropdown_fields).returns([contact_field('cf_custom_text')])
    controller_params = { 'name' => 'test', 'custom_fields' => { 'cf_custom_text' => 'text' } }
    contact = ContactValidation.new(controller_params, nil)
    assert contact.valid?
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

  def test_contact_with_other_emails_empty
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      name: Faker::Lorem.characters(15),
      email: nil, 
      other_emails: [],
      phone: Faker::Lorem.characters(10)
    }
    item = nil
    contact_create = ContactValidation.new(controller_params, item)
    assert contact_create.valid?
    assert contact_create.errors.full_messages.empty?
    contact_update = ContactValidation.new(controller_params, item)
    assert contact_update.valid?(:update)
    assert contact_update.errors.full_messages.empty?
  end

  def test_name_invalid_create
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    ['sam https://www.test.com', 'test name/cont "', 'bitly.cc/test', 'localhost:8070/',
     'https://facebook.com', '192.168.123.12:8080/', 'https://192.168.1.3/', 'mail.google.com/'].each do |name|
      controller_params = { name: name, email: Faker::Internet.email }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:create)
      assert_equal({
        email: {},
        name: {
          pattern: '/,",www.',
          field: :name,
          code: :invalid_format
        }
      }, contact.error_options)
    end
  end

  def test_name_invalid_update
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    ['sam https://www.test.com', 'test name/cont "', 'bitly.cc/test', 'localhost:8070/',
     'https://facebook.com', '192.168.123.12:8080/', 'https://192.168.1.3/', 'mail.google.com/'].each do |name|
      controller_params = { name: name, email: Faker::Internet.email }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:update)
      assert_equal({
        email: {},
        name: {
          pattern: '/,",www.',
          field: :name,
          code: :invalid_format
        }
      }, contact.error_options)
    end
  end

  def test_name_valid_create
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    ['test name / sime', 'test.notadomain/sime', 'test.domain', 'firstname lastname',
     'first/name last/name', 'firstname.lastname'].each do |name|
      controller_params = { name: name, email: Faker::Internet.email }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      assert contact.valid?(:create)
    end
  end

  def test_name_valid_update
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    ['test name / sime', 'test.notadomain/sime', 'test.domain', 'firstname lastname',
     'first/name last/name', 'firstname.lastname'].each do |name|
      controller_params = { name: name, email: Faker::Internet.email }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      assert contact.valid?(:update)
    end
  end

  def test_contact_create_without_name
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = { email: Faker::Internet.email }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    assert contact.valid?
  end

  private

    def contact_field(name)
      contact_field = ContactField.new
      contact_field.name = name
      contact_field.field_type = 'custom_text'
      contact_field
    end
end

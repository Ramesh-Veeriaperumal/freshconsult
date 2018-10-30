require_relative '../unit_test_helper'

class ContactMergeValidationTest < ActionView::TestCase
  def self.fixture_path
    File.join(Rails.root, 'test/api/fixtures/')
  end

  def teardown
    Account.unstub(:current)
    Account.any_instance.unstub(:contact_form)
    ContactForm.unstub(:default_contact_fields)
    super
  end

  def test_merge_contact_company_ids_valid
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    Account.any_instance.stubs(:has_feature?).with(:multiple_user_companies).returns(true)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      'primary_contact_id' => 1,
      'secondary_contact_ids' => [1, 2, 3],
      'contact' => {
        phone: "9999999999",
        email: "test@g.com",
        mobile: "8888888888",
        twitter_id: "someString",
        fb_profile_id: "someString",
        other_emails: ["a@g.com", "b@g.com"],
        company_ids: [1, 2]
      }
    }
    item = User.new({'name' => 'test', :email => Faker::Internet.email})
    contact = ContactMergeValidation.new(controller_params, item)
    assert contact.valid?
  end

  def test_merge_contact_company_ids_invalid
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      'primary_contact_id' => 1,
      'secondary_contact_ids' => [1, 2, 3],
      'contact' => {
        phone: "9999999999",
        mobile: "8888888888",
        twitter_id: "someString",
        fb_profile_id: "someString",
        other_emails: ["a@g.com", "b@g.com"],
        company_ids: ["1"]
      }
    }
    item = User.new({'name' => 'test', :email => Faker::Internet.email})
    contact = ContactMergeValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Company ids array_datatype_mismatch')
  end

  def test_company_ids_string
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      'primary_contact_id' => 1,
      'secondary_contact_ids' => [1, 2, 3],
      'contact' => {
        phone: "9999999999",
        mobile: "8888888888",
        twitter_id: "someString",
        fb_profile_id: "someString",
        other_emails: ["a@g.com", "b@g.com"],
        company_ids: "1"
      }
    }
    item = User.new({'name' => 'test', :email => Faker::Internet.email})
    contact = ContactMergeValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Company ids datatype_mismatch')
  end

  def test_company_ids_invalid_number
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      'primary_contact_id' => 1,
      'secondary_contact_ids' => [1, 2, 3],
      'contact' => {
        phone: "9999999999",
        mobile: "8888888888",
        twitter_id: "someString",
        fb_profile_id: "someString",
        other_emails: ["a@g.com", "b@g.com"],
        company_ids: [-1]
      }
    }
    item = User.new({'name' => 'test', :email => Faker::Internet.email})
    contact = ContactMergeValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Company ids array_datatype_mismatch')
  end

  def test_company_ids_max_count
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    companies = []
    (1..21).each do |i|
      companies << i
    end
    controller_params = {
      'primary_contact_id' => 1,
      'secondary_contact_ids' => [1, 2, 3],
      'contact' => {
        phone: "9999999999",
        mobile: "8888888888",
        twitter_id: "someString",
        fb_profile_id: "someString",
        other_emails: ["a@g.com", "b@g.com"],
        company_ids: companies
      }
    }
    item = User.new({'name' => 'test', :email => Faker::Internet.email})
    contact = ContactMergeValidation.new(controller_params, item)
    refute contact.valid?
  end

  def test_merge_contact_company_ids_duplicate
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      'primary_contact_id' => 1,
      'secondary_contact_ids' => [1, 2, 3],
      'contact' => {
        phone: "9999999999",
        mobile: "8888888888",
        twitter_id: "someString",
        fb_profile_id: "someString",
        other_emails: ["a@g.com", "b@g.com"],
        company_ids: [1, 1]
      }
    }
    item = User.new({'name' => 'test', :email => Faker::Internet.email})
    contact = ContactMergeValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Company ids duplicate_companies')
  end

  def test_invalid_params
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    item = User.new({'name' => 'test', :email => Faker::Internet.email})
    controller_params = { 'primary_contact_id' => 'XYZ', 'secondary_contact_ids' => 'ABC', 'contact' => 'ABC' }
    merge_validation = ContactMergeValidation.new(controller_params, nil)
    refute merge_validation.valid?
    errors = merge_validation.errors.full_messages
    assert errors.include?('Primary contact datatype_mismatch')
    assert errors.include?('Secondary contact ids datatype_mismatch')
    assert errors.include?('Contact datatype_mismatch')
    controller_params = {'primary_contact_id' => 1, 'secondary_contact_ids' => ['ABC']}
    merge_validation = ContactMergeValidation.new(controller_params, nil)
    refute merge_validation.valid?
    errors = merge_validation.errors.full_messages
    assert errors.include?('Secondary contact ids array_datatype_mismatch')
  end

  def test_validation_success
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    Account.any_instance.stubs(:has_feature?).with(:multiple_user_companies).returns(true)
    controller_params = {
      company_ids: [1, 1]
    }
    item = User.new({'name' => 'test', :email => Faker::Internet.email})
    target_item = User.new({'name' => Faker::Name.name, :email => Faker::Internet.email})

    controller_params = {
      'primary_contact_id' => 1,
      'secondary_contact_ids' => [1, 2, 3],
      'contact' => {
        phone: "9999999999",
        mobile: "8888888888",
        twitter_id: "someString",
        fb_profile_id: "someString",
        other_emails: ["a@g.com", "b@g.com"],
        company_ids: [1, 2]
      }
    }
    merge_validation = ContactMergeValidation.new(controller_params, item)
    assert merge_validation.valid?
  end

  def test_validation_success_without_primary_email
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    Account.any_instance.stubs(:has_feature?).with(:multiple_user_companies).returns(true)
    controller_params = {
      company_ids: [1, 1]
    }
    item = User.new({'name' => 'test', :email => Faker::Internet.email})
    target_item = User.new({'name' => Faker::Name.name, :phone => Faker::Number.number(10)})

    controller_params = {
      'primary_contact_id' => 1,
      'secondary_contact_ids' => [1, 2, 3],
      'contact' => {
        phone: "9999999999",
        mobile: "8888888888",
        twitter_id: "someString",
        fb_profile_id: "someString",
        other_emails: ["a@g.com", "b@g.com"],
        company_ids: [1, 2]
      }
    }
    merge_validation = ContactMergeValidation.new(controller_params, item)
    assert merge_validation.valid?
  end

  def test_invalid_phone
    Account.stubs(:current).returns(Account.new)
    controller_params = {
      'primary_contact_id' => 1,
      'secondary_contact_ids' => [1, 2, 3],
      'contact' => {
        phone: 9999999999
      }
    }
    merge_validation = ContactMergeValidation.new(controller_params, nil)
    refute merge_validation.valid?
    errors = merge_validation.errors.full_messages
    assert errors.include?('Phone datatype_mismatch')
  end

    def test_invalid_mobile
      Account.stubs(:current).returns(Account.new)
      controller_params = {
        'primary_contact_id' => 1,
        'secondary_contact_ids' => [1, 2, 3],
        'contact' => {
          mobile: 8888888888
        }
      }
      merge_validation = ContactMergeValidation.new(controller_params, nil)
      refute merge_validation.valid?
      errors = merge_validation.errors.full_messages
      assert errors.include?('Mobile datatype_mismatch')
    end

    def test_invalid_fb_profile_id
      Account.stubs(:current).returns(Account.new)
      controller_params = {
        'primary_contact_id' => 1,
        'secondary_contact_ids' => [1, 2, 3],
        'contact' => {
          fb_profile_id: 8888
        }
      }
      merge_validation = ContactMergeValidation.new(controller_params, nil)
      refute merge_validation.valid?
      errors = merge_validation.errors.full_messages
      assert errors.include?('Fb profile datatype_mismatch')
    end

    def test_invalid_external_id
      Account.stubs(:current).returns(Account.new)
      controller_params = {
        'primary_contact_id' => 1,
        'secondary_contact_ids' => [1, 2, 3],
        'contact' => {
          external_id: 8888
        }
      }
      merge_validation = ContactMergeValidation.new(controller_params, nil)
      refute merge_validation.valid?
      errors = merge_validation.errors.full_messages
      assert errors.include?('External datatype_mismatch')
    end

    def test_other_emails_invalid
      Account.stubs(:current).returns(Account.new)
      controller_params = {
        'primary_contact_id' => 1,
        'secondary_contact_ids' => [1, 2, 3],
        'contact' => {
          other_emails: [1]
        }
      }
      contact = ContactMergeValidation.new(controller_params, nil)
      refute contact.valid?
      errors = contact.errors.full_messages
      assert errors.include?('Other emails array_invalid_format')
    end

    def test_other_emails_string
      Account.stubs(:current).returns(Account.new)
      controller_params = {
        'primary_contact_id' => 1,
        'secondary_contact_ids' => [1, 2, 3],
        'contact' => {
          other_emails: "a@g.com"
        }
      }
      contact = ContactMergeValidation.new(controller_params, nil)
      refute contact.valid?
      errors = contact.errors.full_messages
      assert errors.include?('Other emails datatype_mismatch')
    end

    def test_other_emails_max_count
      Account.stubs(:current).returns(Account.new)
      emails = []
      (1..10).each do |i|
        emails << Faker::Internet.email
      end
      controller_params = {
        'primary_contact_id' => 1,
        'secondary_contact_ids' => [1, 2, 3],
        'contact' => {
          other_emails: emails
        }
      }
      contact = ContactMergeValidation.new(controller_params, nil)
      refute contact.valid?
    end

  def test_unique_external_id_without_feature
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    Account.any_instance.stubs(:has_feature?).with(:unique_contact_identifier).returns(false)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      primary_contact_id: 1,
      secondary_contact_ids: [1, 2, 3],
      contact: {
        phone: "9999999999",
        email: "test@g.com",
        mobile: "8888888888",
        twitter_id: "someString",
        fb_profile_id: "someString",
        unique_external_id: "someString",
        other_emails: ["a@g.com", "b@g.com"]
      }
    }
    item = User.new({ 'name' => 'test', :email => Faker::Internet.email })
    contact = ContactMergeValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Unique external require_feature_for_attribute')
  end

  def test_multiple_company_ids_without_feature
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    Account.any_instance.stubs(:has_feature?).with(:multiple_user_companies).returns(false)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      primary_contact_id: 1,
      secondary_contact_ids: [1, 2, 3],
      contact: {
        phone: "9999999999",
        email: "test@g.com",
        mobile: "8888888888",
        twitter_id: "someString",
        fb_profile_id: "someString",
        other_emails: ["a@g.com", "b@g.com"],
        company_ids: [1, 2]
      }
    }
    item = User.new({ 'name' => 'test', :email => Faker::Internet.email })
    contact = ContactMergeValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Company ids require_feature_for_multiple_companies')
  end

  def test_other_emails_presence_with_empty_email
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([])
    controller_params = {
      primary_contact_id: 1,
      secondary_contact_ids: [1, 2, 3],
      contact: {
        phone: "9999999999",
        email: nil,
        mobile: "8888888888",
        twitter_id: "someString",
        fb_profile_id: "someString"
      }
    }
    item = User.new({ 'name' => 'test', :email => Faker::Internet.email })
    contact = ContactMergeValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Other emails should_be_set_as_blank')
  end
end

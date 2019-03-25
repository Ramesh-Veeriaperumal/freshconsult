require_relative '../../../unit_test_helper'
require_relative '../../contact_validation_test.rb'
Rails.root.join('test', 'api', 'helpers', 'custom_field_validator_test_helper.rb')

module Channel::V2
  class ContactValidationTest < ContactValidationTest
    def test_create_with_created_at_updated_at
      Account.stubs(:current).returns(Account.first)
      time_now = Time.now.utc
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'created_at' => time_now, 'updated_at' => time_now }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      assert contact.valid?(:channel_contact_create)
    end

    def test_created_at_string
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'created_at' => 'string', 'updated_at' => Time.now.utc }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Created at invalid_date')
      Account.unstub(:current)
    end

    def test_created_at_nil
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'created_at' => nil, 'updated_at' => Time.now.utc }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Updated at dependent_timestamp_missing')
      Account.unstub(:current)
    end

    def test_updated_at_nil
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'created_at' => Time.now.utc, 'updated_at' => nil }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Created at dependent_timestamp_missing')
      Account.unstub(:current)
    end

    def test_updated_at_created_at_nil
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'created_at' => nil, 'updated_at' => nil }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Created at dependent_timestamp_missing')
      assert errors.include?('Updated at dependent_timestamp_missing')
      Account.unstub(:current)
    end

    def test_created_at_without_updated_at
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'created_at' => Time.now.utc }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Created at dependent_timestamp_missing')
      assert_equal({
                     email: {}, name: {},
                     created_at: { dependent_timestamp: :updated_at, code: :missing_field }
                   }, contact.error_options)

      Account.unstub(:current)
    end

    def test_updated_at_without_created_at
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'updated_at' => Time.now.utc }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Updated at dependent_timestamp_missing')
      assert_equal({
                     email: {}, name: {},
                     updated_at: { dependent_timestamp: :created_at, code: :missing_field }
                   }, contact.error_options)
      Account.unstub(:current)
    end

    def test_created_at_gt_current_time
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'created_at' => (Time.now.utc + 10.minutes),
                            'updated_at' => Time.now.utc }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Created at start_time_lt_now')
      Account.unstub(:current)
    end

    def test_updated_at_lt_created_at
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'created_at' => Time.now.utc,
                            'updated_at' => (Time.now.utc - 10.minutes) }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Updated at gt_created_and_now')
      Account.unstub(:current)
    end

    def test_updated_at_gt_current_time
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'created_at' => Time.now.utc - 10.minutes,
                            'updated_at' => (Time.now.utc + 10.minutes) }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Updated at start_time_lt_now')
      Account.unstub(:current)
    end

    def test_integer_fields_failure
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'import_id' => 'test',
                            'login_count' => 'test',
                            'failed_login_count' => 'test',
                            'parent_id' => 'test',
                            'posts_count' => 'test',
                            'user_role' => 'test' }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Import is not a number')
      assert errors.include?('Login count is not a number')
      assert errors.include?('Failed login count is not a number')
      assert errors.include?('Parent is not a number')
      assert errors.include?('Posts count is not a number')
      assert errors.include?('User role is not a number')

      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'import_id' => -1,
                            'login_count' => -123,
                            'failed_login_count' => -123,
                            'parent_id' => -12,
                            'posts_count' => -123,
                            'user_role' => -12 }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Import must be greater than or equal to 0')
      assert errors.include?('Login count must be greater than or equal to 0')
      assert errors.include?('Failed login count must be greater than or equal to 0')
      assert errors.include?('Parent must be greater than or equal to 0')
      assert errors.include?('Posts count must be greater than or equal to 0')
      assert errors.include?('User role must be greater than or equal to 0')

      Account.unstub(:current)
    end

    def test_integer_fields_success
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'import_id' => 123,
                            'login_count' => nil,
                            'failed_login_count' => 0,
                            'parent_id' => 123,
                            'posts_count' => 12,
                            'user_role' => nil }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      assert contact.valid?(:channel_contact_create)
      Account.unstub(:current)
    end

    def test_string_fields_success
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'facebook_id' => 'test',
                            'external_id' => 'test',
                            'crypted_password' => 'test',
                            'password_salt' => 'test',
                            'current_login_ip' => 'test',
                            'second_email' => 'test',
                            'last_login_ip' => 'test',
                            'privileges' => 'test',
                            'extn' =>  'test' }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      assert contact.valid?(:channel_contact_create)
      Account.unstub(:current)
    end

    def test_string_fields_failure
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'facebook_id' => 123,
                            'external_id' => 1,
                            'crypted_password' => 0,
                            'password_salt' => 123,
                            'current_login_ip' => 1,
                            'second_email' => 123,
                            'last_login_ip' => 1234,
                            'privileges' => 12_341,
                            'extn' => 123 }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Facebook datatype_mismatch')
      assert errors.include?('External datatype_mismatch')
      assert errors.include?('Crypted password datatype_mismatch')
      assert errors.include?('Password salt datatype_mismatch')
      assert errors.include?('Current login ip datatype_mismatch')
      assert errors.include?('Second email datatype_mismatch')
      assert errors.include?('Last login ip datatype_mismatch')
      assert errors.include?('Privileges datatype_mismatch')
      assert errors.include?('Extn datatype_mismatch')

      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'facebook_id' => Faker::Lorem.characters(300),
                            'external_id' => Faker::Lorem.characters(300),
                            'crypted_password' => Faker::Lorem.characters(300),
                            'password_salt' => Faker::Lorem.characters(300),
                            'current_login_ip' => Faker::Lorem.characters(300),
                            'second_email' => Faker::Lorem.characters(300),
                            'last_login_ip' => Faker::Lorem.characters(300),
                            'privileges' => Faker::Lorem.characters(300),
                            'extn' => Faker::Lorem.characters(300) }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Facebook too_long')
      assert errors.include?('External too_long')
      assert errors.include?('Crypted password too_long')
      assert errors.include?('Password salt too_long')
      assert errors.include?('Current login ip too_long')
      assert errors.include?('Second email too_long')
      assert errors.include?('Last login ip too_long')
      assert errors.include?('Privileges too_long')
      assert errors.include?('Extn too_long')

      Account.unstub(:current)
    end

    def test_date_fields_failure
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'blocked_at' => 123,
                            'deleted_at' => 1,
                            'last_login_at' => 0,
                            'current_login_at' => 123,
                            'last_seen_at' => 123 }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Blocked at invalid_date')
      assert errors.include?('Deleted at invalid_date')
      assert errors.include?('Last login at invalid_date')
      assert errors.include?('Current login at invalid_date')
      assert errors.include?('Last seen at invalid_date')
    end

    def test_hash_fields_failure
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'preferences' => Time.now.utc,
                            'history_column' => 'test' }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Preferences datatype_mismatch')
    end

    def test_hash_fields_success
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'preferences' => { agent_preferences: {},
                                               user_preferences: {} },
                            'history_column' => {
                              password_history: [{ password: 'test', salt: 'test' }]
                            } }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      assert contact.valid?(:channel_contact_create)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'preferences' => nil,
                            'history_column' => nil }
      contact = ContactValidation.new(controller_params, item)
      assert contact.valid?(:channel_contact_create)
    end

    def test_date_fields_success
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'blocked_at' => Time.now.utc,
                            'deleted_at' => Time.now.utc,
                            'last_login_at' => nil,
                            'current_login_at' => Time.now.utc,
                            'last_seen_at' => Time.now.utc }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      assert contact.valid?(:channel_contact_create)
    end

    def test_boolean_fields_success
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'deleted' => false,
                            'blocked' => false,
                            'whitelisted' => nil,
                            'delta' => false }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      assert contact.valid?(:channel_contact_create)
    end

    def test_boolean_fields_failure
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'deleted' => Time.now.utc,
                            'blocked' => Time.now.utc,
                            'whitelisted' => Time.now.utc,
                            'delta' => 'test' }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Deleted datatype_mismatch')
      assert errors.include?('Blocked datatype_mismatch')
      assert errors.include?('Whitelisted datatype_mismatch')
      assert errors.include?('Delta datatype_mismatch')
    end

    def test_active_success
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'active' => false, 'import_id' => 123 }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      assert contact.valid?(:channel_contact_create)
    end

    def test_active_failure
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'active' => "test", 'import_id' => 123 }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Active datatype_mismatch')
    end

    def test_language_timezone_validation_success
      Account.stubs(:current).returns(Account.first)
      Account.any_instance.stubs(:features?).with(:multi_language).returns(true)
      Account.any_instance.stubs(:multi_timezone_enabled?).returns(true)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'language' => 'en',
                            'timezone' => 'America/Los_Angeles' }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      assert contact.valid?(:channel_contact_create)
    end

    def test_language_timezone_validation_failure
      Account.any_instance.stubs(:features?).with(:multi_language).returns(false)
      Account.any_instance.stubs(:features?).with(:multi_timezone).returns(false)

      Account.any_instance.stubs(:multi_timezone_enabled?).returns(false)
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'name' => 'test', :email => Faker::Internet.email,
                            'language' => 'en',
                            'timezone' => 'America/Los_Angeles' }
      item = nil
      contact = ContactValidation.new(controller_params, item)
      refute contact.valid?(:channel_contact_create)
      errors = contact.errors.full_messages
      assert errors.include?('Language require_feature_for_attribute')
      assert errors.include?('Timezone require_feature_for_attribute')
    end
  end
end

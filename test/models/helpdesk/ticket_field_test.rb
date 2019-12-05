require_relative '../test_helper'

class TicketFieldTest < ActiveSupport::TestCase
  include DataStoreTestHelper

  def test_update_ticket_field_cache_clear
    field_name = 'description'
    new_label = 'Description one'
    tkt_field = @account.ticket_fields.find_by_name(field_name)
    @account.all_languages.each do |lang|
      MemcacheKeys.expects(:delete_from_cache).with(ticket_field_memcache_key(lang)).once
    end
    tkt_field.update_attributes(label_in_portal: new_label)
  end

  def test_update_ticket_field_cache_clear_with_supported_language
    field_name = 'description'
    new_label = 'Description two'
    tkt_field = @account.ticket_fields.find_by_name(field_name)
    Account.any_instance.stubs(:all_languages).returns([@account.language, 'fr', 'ca'])
    @account.all_languages.each do |lang|
      MemcacheKeys.expects(:delete_from_cache).with(ticket_field_memcache_key(lang)).once
    end
    tkt_field.update_attributes(label_in_portal: new_label)
    Account.any_instance.unstub(:all_languages)
  end

  def test_update_ticket_field_with_account_version_update
    field_name = 'description'
    new_label = 'Description three'
    tkt_field = @account.ticket_fields.find_by_name(field_name)
    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    tkt_field.expects(:set_others_redis_hash_set).with(account_data_version_key, Helpdesk::TicketField::VERSION_MEMBER_KEY, time_now.utc.to_i)
    tkt_field.update_attributes(label_in_portal: new_label)
    Time.unstub(:now)
  end

  def test_field_name_helper_base
    label = "test"
    account_id = 1
    expected_field_name = "cf_test_1"
    field_name = Helpdesk::TicketField.field_name(label, account_id)
    assert_match(expected_field_name, field_name)
  end

  def test_field_name_helper_encrypted_field
    label = "test"
    account_id = 1
    expected_field_name = "cf_enc_test_1"
    field_name = Helpdesk::TicketField.field_name(label, account_id, false, true)
    assert_match(expected_field_name, field_name)
  end

  def test_field_name_helper_random
    label = "test"
    account_id = 1
    field_name = Helpdesk::TicketField.field_name(label, account_id, true)
    random = field_name.split('_')[1]
    assert(random.include?(label) && random != label)
  end

  def test_field_name_helper_random_with_non_alpha_characters
    label = ""
    account_id = 1
    field_name = Helpdesk::TicketField.field_name(label, account_id)
    random = field_name.split('_')[1]
    assert(random.include?('rand') && random != 'rand')
  end

  def test_field_name_helper_random_and_non_alpha_characters
    label = ""
    account_id = 1
    field_name = Helpdesk::TicketField.field_name(label, account_id, true)
    random = field_name.split('_')[1]
    assert(random.include?('rand') && random != 'rand')
  end
end
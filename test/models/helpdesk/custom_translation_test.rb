require_relative '../test_helper'

class CustomTranslationTest < ActiveSupport::TestCase
  include DataStoreTestHelper

  def test_custom_translation_ticket_field_cache_clear
    language = 'fr'
    custom_translation_stub(language) do
      @account.all_languages.each do |lang|
        MemcacheKeys.expects(:delete_from_cache).with(ticket_field_memcache_key(lang)).never
      end
      # translation update and destroy, so it expects twice
      MemcacheKeys.expects(:delete_from_cache).with(ticket_field_memcache_key(language)).twice
      @translation_record.update_attributes(translations: { 'customer_label' => 'test' })
    end
  end

  def test_custom_translation_ticket_field_account_version_update
    language = 'fr'
    custom_translation_stub(language) do
      time_now = Time.now
      Time.stubs(:now).returns(time_now)
      # translation update and destroy, so it expects twice
      @translation_record.expects(:set_others_redis_hash_set).with(account_data_version_key, custom_translation_key(language), time_now.utc.to_i).twice
      @translation_record.update_attributes(translations: { 'customer_label' => 'test' })
    end
  end

  private

    def custom_translation_stub(language)
      field_name = 'description'
      new_label = 'Description one'
      trans_association = language + '_translation'
      tkt_field = @account.ticket_fields.find_by_name(field_name)
      tkt_field.safe_send('build_' + trans_association, translations: { 'customer_label' => new_label }).save!
      @translation_record = tkt_field.safe_send(trans_association)
      yield
      @translation_record.destroy
      Time.unstub(:now)
    end
end
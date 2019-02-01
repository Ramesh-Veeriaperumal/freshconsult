module DataStoreTestHelper
  def account_data_version_key
    format(Redis::Keys::PrivateApiKeys::DATA_VERSIONING_SET, account_id: Account.current.id)
  end

  def custom_translation_key(language)
    format(CustomTranslation::VERSION_MEMBER_KEYS['Helpdesk::TicketField'], language_code: language)
  end

  def ticket_field_memcache_key(language)
    format(MemcacheKeys::TICKET_FIELDS_FULL, account_id: Account.current.id, language_code: language)
  end
end

module MemcacheCleaner
  extend ActiveSupport::Concern

  include MemcacheKeys

  MULTIPLE_KEY_CACHE_METHOD = {
    TICKET_FIELDS_FULL => 'clear_ticket_field_response',
    CUSTOMER_EDITABLE_TICKET_FIELDS_FULL => 'clear_ticket_field_response',
    CUSTOMER_EDITABLE_TICKET_FIELDS_WITHOUT_PRODUCT => 'clear_ticket_field_response'
  }.freeze

  included do
    after_commit :clean_memcache_data
  end

  def clean_memcache_data
    begin
      if defined? self.cache_keys_to_delete
        acc_id_hash = { account_id: self.account_id }
        self.cache_keys_to_delete.each do |cache_key|
          result = (MULTIPLE_KEY_CACHE_METHOD.key? cache_key) ? safe_send(MULTIPLE_KEY_CACHE_METHOD[cache_key], cache_key, acc_id_hash) : (MemcacheKeys.delete_from_cache cache_key % acc_id_hash)
          Rails.logger.info "Memcache cleaner :: #{acc_id_hash[:account_id]} :: #{self.class.name} :: #{result.inspect}"
        end
      end
    rescue StandardError => e
      Rails.logger.info "Exception while clean response cache : #{e.message} : #{e.backtrace}"
    end
  end

  module ClassMethods
    def clear_memcache(keys)
      self.send :define_method, "cache_keys_to_delete" do
        keys || []
      end
    end
  end

  private

    def clear_ticket_field_response(cache_key, acc_id_hash)
      language_codes = self.class.name.to_s.eql?('CustomTranslation') ? [Language.find(self.language_id).try(:code)] : Account.current.all_languages
      result = []
      language_codes.each do |code|
        status = (MemcacheKeys.delete_from_cache cache_key % acc_id_hash.merge(language_code: code))
        result << "#{code}:#{status}"
      end
      result
    end
end

ActiveRecord::Base.send :include, MemcacheCleaner
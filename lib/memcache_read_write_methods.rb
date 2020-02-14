module MemcacheReadWriteMethods

  MAX_VERSION = 10

  def newrelic_begin_rescue(&block)
    begin
      block.call
    rescue Dalli::UnmarshalError => e
      x = ['undefined class/module CompanyField', 'undefined class/module ContactFieldChoice',
           'undefined class/module CustomSurvey::SurveyQuestion']
      if x.any? { |word| e.message.include?(word) }
         Rails.logger.debug "#{Account.current}  #{e.message}"
      end
      NewRelic::Agent.notice_error(e)
      return
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      return
    end
  end

  def multi_block_for_cache(&block)
    # Operations are pipelined and are 'quiet'(doesn't wait for the response). get is not supported.
    newrelic_begin_rescue do
      memcache_client.multi do
        yield
      end
    end
  end

  def get_from_cache(key, raw = false)
    newrelic_begin_rescue { memcache_client.get(key, raw) }
  end

  def get_multi_from_cache(keys)
    newrelic_begin_rescue { memcache_client.get_multi(keys) }
  end

  def cache(key, value, expiry = 0, raw = false)
    newrelic_begin_rescue { memcache_client.set(key, value, expiry, raw) }
  end

  def delete_adjacent_keys(key)
    key = key.to_s
    regex = /\Av[0-9]+\//
    version = key.match(regex).to_s
    key_name = key[version.length, key.length]
    return if version.blank? || key_name.blank?

    version_num = version[1, version.length - 2].to_i # get the data between v & / so the version number
    ((version_num - 2)..version_num).each do |delete_version_num|
      delete_version = delete_version_num < 1 ? '' : "v#{delete_version_num}/"
      old_key = delete_version + key_name
      memcache_client.delete old_key
    end
  end

  def delete_from_cache(key)
    newrelic_begin_rescue do
      delete_adjacent_keys(key)
      memcache_client.delete(key)
    end
  end

  def delete_multiple_from_cache(keys)
    Rails.logger.info ":: Deleting keys: #{keys.inspect} ::"
    multi_block_for_cache do
      keys.each { |key| memcache_client.delete(key) }
    end
  end

  def set_null(value)
    value.nil? ? NullObject.instance : value
  end

  def unset_null(value)
    value.is_a?(NullObject) ? nil : value
  end

  def fetch(key, expiry = 0, after_cache_msg = nil, &block)
    key = ActiveSupport::Cache.expand_cache_key(key) if key.is_a?(Array)
    cache_data = get_from_cache(key)
    if cache_data.nil?
      Rails.logger.debug "Cache hit missed :::::: #{key}"
      cache(key, (cache_data = set_null(block.call)), expiry)
    else
      Rails.logger.debug "::::: #{after_cache_msg} :::::: #{key}" if after_cache_msg
    end
    unset_null(cache_data)
  end

  def fetch_unless_empty(key, expiry=0, after_cache_msg = nil, &block)
    key = ActiveSupport::Cache.expand_cache_key(key) if key.is_a?(Array)
    cache_data = get_from_cache(key)
    if cache_data.nil?
      Rails.logger.debug "Cache hit missed :::::: #{key}"
      cache_data = block.call
      cache(key, set_null(cache_data), expiry) unless cache_data.nil?
    else
      Rails.logger.debug "::::: #{after_cache_msg} :::::: #{key}" if after_cache_msg
    end
    unset_null(cache_data)
  end
end

class Redis::KeyValueStore

  include Redis::RedisKeys
  attr_accessor :key, :value, :expire, :group

  REDIS_CONNECTIONS = { 
              :other => $redis_others,
              :integration => $redis_integrations,
              #:portal => $redis_portal,
              #:report => $redis_reports,
              #:ticket => $redis_tickets,
            }.freeze

  def initialize(key_spec, value = nil, options={})
    @key_spec = key_spec #To be removed
    @key = key_spec.to_s
    @value = value
    @expire = options[:expire] || 86400
    @group = REDIS_CONNECTIONS.include?(options[:group]) ? options[:group] : :other
    @redis_client = REDIS_CONNECTIONS[group]
  end

  def get_key
    newrelic_begin_rescue {
      value = redis_client.get(key)
      value.blank? ? get_from_kvp_table : value #To be removed in next deployment
    }
  end

  def set_key
    newrelic_begin_rescue do
      redis_client.set(key, value)
      redis_client.expire(key,expires) if expires
    end
  end

  def remove_key
    newrelic_begin_rescue { redis_client.del(key) }
  end

  def group=(connection_type)
    if REDIS_CONNECTIONS.include?(connection_type)
      group = connection_type
    else
      group = :other
    end
    redis_client = REDIS_CONNECTIONS[group]
  end

  private

    attr_accessor :redis_client, :key_spec

    #to be removed, also the key_spec from accessor
    def get_from_kvp_table
      Rails.logger.info "Redis::KeyValueStore: value not found, trying in KeyValuePair table : #{key_spec} :: #{key_spec.options_hash}"
      if !key_spec.kind_of?(Redis::KeySpec) || key_spec.options_hash.blank?
        return
      end
  
      table_key = nil
      if key_spec.options_hash.key? :token
        table_key = key_spec.options_hash[:token]
      elsif !key_spec.options_hash[:provider].blank?
        provider = key_spec.options_hash[:provider]
        if provider == 'facebook'
          table_key = key_spec.options_hash[:user_id]
        else
          table_key = "#{provider}_oauth_config"
        end
      end
      kvp = KeyValuePair.find_by_account_id_and_key(key_spec.options_hash[:account_id], table_key) unless table_key.blank?
      kvp.blank? ? nil : kvp.delete.value
    end
end
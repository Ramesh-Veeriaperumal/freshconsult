class Redis::KeyValueStore
  include RedisKeys
  
  attr_accessor :key_spec, :value, :expire
  
  def initialize(key_spec = nil, value = nil, expire = 300)
    @key_spec = key_spec
    @value = value if value
    @expire = expire
  end

  def get
    value = get_key(key_spec) if key_spec
    value = get_from_kvp_table if value.nil?
    Rails.logger.info "Redis::KeyValueStore.get #{key_spec} : #{value}"
    value
  end

  def save
    if(key_spec && value)
      set_key(key_spec, value, expire)
      Rails.logger.info "Redis::KeyValueStore.save #{key_spec} : #{value}"
    else
      Rails.logger.info "Redis::KeyValueStore.save - Failed to store : Key -#{key_spec}: Value -#{value}"
    end
  end

  def remove
    val = remove_key(key_spec) if key_spec
    Rails.logger.info "Redis::KeyValueStore.remove #{key_spec} : #{val}"
  end

  private

    #to be removed
    def get_from_kvp_table
      Rails.logger.info "Redis::KeyValueStore: value not found, trying in KeyValuePair table : #{key_spec}"
      if !key_spec.kind_of?(Redis::KeySpec) || key_spec.options.blank?
        return
      end
  
      key = nil
      if key_spec.options.key? :token
        key = key_spec.options[:token]
      elsif !key_spec.options[:provider].blank?
        provider = key_spec.options[:provider]
        if provider == 'facebook'
          key = key_spec.options[:user_id]
        else
          key = "#{provider}_oauth_config"
        end
      end
      kvp = KeyValuePair.find_by_account_id_and_key(key_spec.options[:account_id], key) unless key.blank?
      kvp.blank? ? nil : kvp.delete.value
    end
end
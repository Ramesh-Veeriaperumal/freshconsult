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
    @key = key_spec.to_s
    @value = value
    @expire = options[:expire] || 86400
    @group = REDIS_CONNECTIONS.include?(options[:group]) ? options[:group] : :other
    @redis_client = REDIS_CONNECTIONS[group]
  end

  def get_key
    newrelic_begin_rescue {
      redis_client.get(key)
    }
  end

  def set_key
    newrelic_begin_rescue do
      redis_client.set(key, value)
      redis_client.expire(key,expire) if expire
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

    attr_accessor :redis_client
end
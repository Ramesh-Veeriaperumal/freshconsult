class Search::V2::Store::Cache
  include Singleton

  #################
  ## Cache Keys
  #################

  ALIAS         = "alias:%{tenant_id}:%{type}"
  CLUSTER       = "cluster:%{tenant_id}"
  TENANT        = "tenant:%{tenant_id}"
  TENANT_INFO   = "tenant_info:%{tenant_id}"

  # Can add necessary methods from here:
  # https://github.com/mperham/dalli/blob/master/lib/dalli/client.rb

  def fetch(key, expiry = 0, &block)
    fallback = proc { yield } # Not checking - block_given? - as it should be given.

    error_handle(fallback) do
      $memcache.fetch(key, expiry, nil, &block)
    end
  end

  def remove(key)
    error_handle { $memcache.delete(key) }
  end

  def error_handle(fallback = nil)
    yield
  rescue => e
    # To-Do: Notify to newrelic
    Rails.logger.error "Exception :: #{e.message}"

    # Fallback for when memcache goes down.
    fallback.call if fallback.present?
  end
end

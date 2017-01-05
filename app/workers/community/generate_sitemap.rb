class Community::GenerateSitemap < BaseWorker
  include Redis::RedisKeys
  include Redis::PortalRedis

  sidekiq_options :queue => :generate_sitemap, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(account_id)
    Sharding.select_shard_of(account_id) do
      Sharding.run_on_slave do
        @account = Account.find_by_id(account_id).make_current
        key = SITEMAP_OUTDATED % { :account_id => @account.id }
        if portal_redis_key_exists?(key)
          generate if @account.features_included?(:sitemap)
          remove_portal_redis_key(key)
        end
      end
    end
  end

  private

  def generate
    @account.portals.each do |portal|
      portal.make_current
      portal.clear_sitemap_cache 
      build(portal)
    end
  end

  def build(portal)
    xml = Community::Sitemap.new(portal).build
    path = "sitemap/#{portal.account_id}/#{portal.id}.xml"
    AwsWrapper::S3Object.store(path, xml, S3_CONFIG[:bucket])
    Portal.reset_current_portal 
  end
end
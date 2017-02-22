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
          Rails.logger.info ":::::: GenerateSitemap: Sitemap key is set for account #{account_id} ::::::"
          generate if @account.features?(:sitemap)
          remove_portal_redis_key(key)
          Rails.logger.info ":::::: GenerateSitemap: Sitemap key is removed for account #{account_id} ::::::"
        end
      end
    end
  end

  private

  def generate
    Rails.logger.info ":::::: GenerateSitemap: Sitemap feature is enabled for account #{@account.id} ::::::"
    @account.portals.each do |portal|
      portal.make_current
      portal.clear_sitemap_cache 
      build(portal)
    end
  end

  def build(portal)
    xml = Community::Sitemap.new(portal).build
    Rails.logger.info ":::::: GenerateSitemap: Sitemap xml is built for portal #{portal.id} in account #{portal.account_id} ::::::"
    path = "sitemap/#{portal.account_id}/#{portal.id}.xml"
    AwsWrapper::S3Object.store(path, xml, S3_CONFIG[:bucket])
    Rails.logger.info ":::::: GenerateSitemap: Sitemap xml is uploaded into S3 for portal #{portal.id} in account #{portal.account_id} ::::::"
    Portal.reset_current_portal 
  end
end
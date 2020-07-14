class Community::GenerateSitemap < BaseWorker
  include Redis::RedisKeys
  include Redis::PortalRedis

  sidekiq_options :queue => :generate_sitemap, :retry => 0, :failures => :exhausted

  def perform(account_id)
    Sharding.select_shard_of(account_id) do
      Sharding.run_on_slave do
        @account = Account.find_by_id(account_id).make_current
        key = SITEMAP_OUTDATED % { :account_id => @account.id }
        if portal_redis_key_exists?(key)
          generate if @account.sitemap_enabled?
          remove_portal_redis_key(key)
        end
      end
    end
  end

  private

  def generate
    @account.portals.each do |portal|
      portal.make_current
      build(portal)
      Portal.reset_current_portal
    end
  end

  def build(portal)
    xml = Community::Sitemap.new(portal).build
    Rails.logger.info ":::::: GenerateSitemap: Sitemap xml is built for portal #{portal.id} in account #{portal.account_id} ::::::"
    write_to_s3(xml, portal)
    Rails.logger.info ":::::: GenerateSitemap: Sitemap xml is uploaded into S3 for portal #{portal.id} in account #{portal.account_id} ::::::"
  end

  def write_to_s3(xml, portal)
    path = "sitemap/#{portal.account_id}/#{portal.id}.xml"
    AwsWrapper::S3Object.store(path, xml, S3_CONFIG[:bucket])
  end
end

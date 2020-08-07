class Community::ClearSitemap < BaseWorker
  include MemcacheKeys

  sidekiq_options :queue => :clear_sitemap, :retry => 0, :failures => :exhausted

  def perform(account_id, portal_id)
    key = SITEMAP_KEY % { :account_id => account_id, :portal_id => portal_id }
    MemcacheKeys.delete_from_cache key
    AwsWrapper::S3.delete(S3_CONFIG[:bucket], "sitemap/#{account_id}/#{portal_id}.xml")
    Rails.logger.info ":::::: Sitemap is cleared (cache & S3) for portal #{portal_id} in account #{account_id} ::::::"
  end

end
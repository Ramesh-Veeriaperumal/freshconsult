class Community::ClearSitemap < BaseWorker
  include MemcacheKeys

  sidekiq_options :queue => :clear_sitemap, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(account_id, portal_id)
    key = SITEMAP_KEY % { :account_id => account_id, :portal_id => portal_id }
    MemcacheKeys.delete_from_cache key
    AwsWrapper::S3Object.delete("sitemap/#{account_id}/#{portal_id}.xml", S3_CONFIG[:bucket])
  end

end
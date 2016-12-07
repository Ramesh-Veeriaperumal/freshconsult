class Solution::FlushPortalCache < BaseWorker

  sidekiq_options :queue => :flush_portal_solution_cache, :retry => 1, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    flush_cache args[:obsolete_version]
  end

  private

  def flush_cache cache_version
    @account.portals.each do |portal|
      @account.all_portal_languages.each do |lang_code|
        key_params = { 
          :cache_version => cache_version,
          :account_id => @account.id, 
          :portal_id => portal.id, 
          :language_code => lang_code,
          :company_ids => []
        }
        [:agents, :logged_users].each do |visibility_key|
          key = CustomMemcacheKeys::PORTAL_SOLUTION_CACHE % key_params.merge(
            :visibility_key => Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[visibility_key])
          CustomMemcacheKeys.delete_from_cache(key)
        end
        flush_company_visibility_keys(key_params)
      end
    end
  end

  def flush_company_visibility_keys key_params
    company_visibility_key = Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    @account.solution_customer_folders.pluck("DISTINCT customer_id").each do |company_id|
      key = CustomMemcacheKeys::PORTAL_SOLUTION_CACHE % key_params.merge(:visibility_key => company_visibility_key, :company_ids => company_id)
      CustomMemcacheKeys.delete_from_cache(key)
    end
  end

end

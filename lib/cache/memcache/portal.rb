module Cache::Memcache::Portal

  include MemcacheKeys

  module ClassMethods
    include MemcacheKeys
    def fetch_by_url(url)
      return if url.blank?
      key = PORTAL_BY_URL % { :portal_url => url }
      MemcacheKeys.fetch(key) { self.find(:first, :conditions => { :portal_url => url }) }
    end
  end

  def self.included(base)
    base.extend ClassMethods
  end

  def clear_portal_cache

    (@all_changes && @all_changes[:portal_url] || [] ).each do |url|
      key = PORTAL_BY_URL % { :portal_url => url}
      MemcacheKeys.delete_from_cache key
    end
    
    key = PORTAL_BY_URL % { :portal_url => @old_object.portal_url}
    MemcacheKeys.delete_from_cache key

    key = ACCOUNT_MAIN_PORTAL % { :account_id => @old_object.account_id }
    MemcacheKeys.delete_from_cache key
  end

  def fetch_template
    key = PORTAL_TEMPLATE % { :account_id => self.account_id, :portal_id => self.id }
    MemcacheKeys.fetch(key) { ::Portal::Template.where(portal_id: self.id).first }
  end

  def solution_categories_from_cache
    CustomMemcacheKeys.fetch(current_solution_cache_key, 0, "SOLUTION PORTAL CACHE FETCH for account ##{Account.current.id}") do
      Solution::CategoryMeta.joins(
        :portal_solution_categories).where(
        "`portal_solution_categories`.portal_id = #{self.id} AND " +
        "`portal_solution_categories`.account_id = #{self.account_id} AND " +
        "`solution_category_meta`.is_default = 0 AND " +
        "`solution_category_meta`.account_id = #{self.account_id}").order("`portal_solution_categories`.position").all
    end
  end

  def current_solution_cache_key
    key_params = { 
      :cache_version => solution_cache_version,
      :account_id => self.account_id, 
      :portal_id => self.id, 
      :language_code => (Language.current || Language.for_current_account).code,
      :visibility_key => current_visibility_key,
      :company_ids => current_customer_folder_ids.join(",")}
    CustomMemcacheKeys::PORTAL_SOLUTION_CACHE % key_params
  end

  def current_visibility_key
    visibility_keys_by_token = Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN 
    return visibility_keys_by_token[:agents] if User.current.privilege?(:manage_tickets)
    return visibility_keys_by_token[:company_users] if current_customer_folder_ids.present?
    visibility_keys_by_token[:logged_users]
  end

  def current_customer_folder_ids
    @current_customer_folder_ids ||= (User.current.company_ids.select do |company_id|
      (Account.current.solution_customer_folders.count(:conditions => {:customer_id => company_id}) > 0)
    end).sort
  end

  def solution_cache_version
    key = Redis::RedisKeys::SOLUTIONS_PORTAL_CACHE_VERSION % { :account_id => self.account_id }
    get_portal_redis_key(key) || "0"
  end
end
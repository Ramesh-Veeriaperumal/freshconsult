module Cache::Memcache::Dashboard::CacheData

  include MemcacheKeys
  include Redis::OthersRedis
  include Redis::RedisKeys

  def workload_from_cache(workload_name, cache_identifier, group_by)
    key = DASHBOARD_WORKLOAD % {:account_id => Account.current.id, :cache_identifier => cache_identifier, :workload_name => workload_name, :group_by => group_by}
    cache_and_notify_redis(key, "admin")
  end

  def groupwise_cached_data(workload_name, cache_identifier, group_by)
    key = DASHBOARD_WORKLOAD_GROUPWISE % {:account_id => Account.current.id, :cache_identifier => cache_identifier, :workload_name => workload_name, :group_by => group_by}
    cache_and_notify_redis(key, "group")
  end

  def redshift_cache_data memcachekey, process, cache_identifier = "redshift_cache_identifier"
    result_data = MemcacheKeys.newrelic_begin_rescue {
      key = memcachekey % {:account_id => Account.current.id, :cache_identifier => safe_send(cache_identifier), :user_id => User.current.id}
      data = MemcacheKeys.get_from_cache(key)
      redis_key = key.split(":").first
      if (data.present? || data.is_a?(Array))
        increment_others_redis("#{redis_key}_GET")
        return MemcacheKeys.unset_null(data)
      end
      data, expiry = safe_send(process)
      cache_data = MemcacheKeys.set_null(data)
      MemcacheKeys.cache(key, cache_data, expiry) if expiry.present?
      increment_others_redis("#{redis_key}_SET")
      MemcacheKeys.unset_null(cache_data)
    }
    return result_data if (result_data.present? || result_data.is_a?(Array))
    redshift_cache_error_response
  end

  private

  def redshift_cache_error_response
    {errors: I18n.t("helpdesk.realtime_dashboard.something_went_wrong")}
  end

  #This method caches data to memcache and sets a redis key while caching and also while fetching.
  #To monitor how effectively caching is used by customers.
  #No of sets and gets will say the no of times its being cached and its being used respectively(cache time is 10 mins.)
  def cache_and_notify_redis(key, cache_type)
    to_be_cached = {}
    begin
      cache_data = MemcacheKeys.get_from_cache(key)
      if cache_data.present?
        increment_others_redis(widgets_redis_key(cache_type, "get"))
        return MemcacheKeys.unset_null(cache_data)
      else
        Rails.logger.debug "Cache hit missed :::::: #{key}"
        to_be_cached = aggregated_data
        #setting a key ttl as there is no way to get ttl of a key from memcache. This will be given back to UI to show as label "time since..."
        to_be_cached.merge!({:time_since => Time.zone.now.to_i})
        cache_data = MemcacheKeys.set_null(to_be_cached)
        MemcacheKeys.cache(key, cache_data, MemcacheKeys::DASHBOARD_TIMEOUT)
        increment_others_redis(widgets_redis_key(cache_type, "set"))
      end
      cache_data.presence || to_be_cached
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      to_be_cached.presence || aggregated_data
    end
  end

  def redshift_cache_identifier
    cache_identifier = if ( @req_params.present? && @req_params[:group_id].present? && (@req_params[:group_id].split(",").length == 1) )
       "GROUP:#{@req_params[:group_id]}"
    elsif (User.current.can_view_all_tickets? && @req_params[:group_id].blank?)
      "PERMISSION:#{User.current.agent.ticket_permission}"
    else
      "USER:#{User.current.id}"
    end
    User.current.assigned_ticket_permission ? "#{cache_identifier}:USER:#{User.current.id}" : cache_identifier
  end

  def redshiftv2_cache_identifier
    cache_identifier = ""
    cache_identifier = cache_identifier + ":GROUP:#{@req_params[:group_id]}" if @req_params.present? && @req_params[:group_id].present? &&  (@req_params[:group_id].split(",").length == 1)
    cache_identifier = cache_identifier + ":PRODUCT:#{@req_params[:product_id]}" if @req_params.present? && @req_params[:product_id].present? &&  (@req_params[:product_id].split(",").length == 1)

    cache_identifier = cache_identifier + ":USER:#{User.current.id}" if(User.current.group_ticket_permission || User.current.can_view_all_tickets?)

    User.current.assigned_ticket_permission ? "#{cache_identifier}:USER:#{User.current.id}" : cache_identifier
  end

  def redshift_custom_dashboard_cache_identifier
    cache_identifier = ""
    cache_identifier << ":METRIC:#{@req_params[:metric]}" if @req_params && @req_params[:metric]
    cache_identifier << ":GROUP:#{@req_params[:group_id]}" if @req_params && @req_params[:group_id]
    cache_identifier << ":PRODUCT:#{@req_params[:product_id]}" if @req_params && @req_params[:product_id]
    cache_identifier
  end

  def widgets_redis_key(cache_type, method)
    if cache_type == "admin"
      if method == "set"
        ADMIN_WIDGET_CACHE_SET % {:account_id => Account.current.id}
      else
        ADMIN_WIDGET_CACHE_GET % {:account_id => Account.current.id}
      end
    else
      if method == "set"
        GROUP_WIDGET_CACHE_SET % {:account_id => Account.current.id}
      else
        GROUP_WIDGET_CACHE_GET % {:account_id => Account.current.id}
      end
    end
  end
end

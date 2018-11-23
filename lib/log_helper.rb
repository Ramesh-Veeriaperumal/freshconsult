module LogHelper
  # Please inform devops when any change is made in the log_file_format
  # We need to make the corresponding change in sumologic(for indexing data) and in the recipe for UnityMedia (parsed application.log)

  def log_format payload
    performance_metrics = TimeBandits.metrics
    "uuid=#{payload[:uuid]}, error=#{payload[:error]}, ip=#{payload[:ip]}, a=#{payload[:account_id]}, u=#{payload[:user_id]}, s=#{payload[:shard_name]}, d=#{payload[:domain]}, url=#{payload[:url]}, path=#{payload[:path]}, c=#{payload[:controller]}, action=#{payload[:action]}, host=#{payload[:server_ip]}, status=#{payload[:status]}, format=#{payload[:format]}, db=#{payload[:db_runtime]}, view=#{payload[:view_runtime]}, redis=[#{performance_metrics[:redis_time].round(2)},#{performance_metrics[:redis_calls]}c], memcache=[#{performance_metrics[:memcache_time].round(2)},#{performance_metrics[:memcache_reads]}r,#{performance_metrics[:memcache_misses]}m,#{performance_metrics[:memcache_writes]}w,#{performance_metrics[:memcache_calls]}c], duration=#{payload[:duration]}"
  end
end

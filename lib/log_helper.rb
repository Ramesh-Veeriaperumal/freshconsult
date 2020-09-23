module LogHelper
  # Please inform devops when any change is made in the log_file_format
  # We need to make the corresponding change in sumologic(for indexing data) and in the recipe for UnityMedia (parsed application.log)

  def log_format(payload)
    performance_metrics = TimeBandits.metrics
    # for trimming the query params
    payload[:url] = payload[:url].split('?')[0] unless payload[:url].nil?
    payload[:path] = payload[:path].split('?')[0] unless payload[:path].nil?
    "id=#{payload[:uuid]},  tp=#{payload[:traceparent]}, cid=#{payload[:client_id]}, wid=#{payload[:widget_id]}, e=#{payload[:error]}, ip=#{payload[:ip]}, a=#{payload[:account_id]}, u=#{payload[:user_id]}, s=#{payload[:shard_name]}, "\
     "d=#{payload[:domain]}, url=#{payload[:url]}, p=#{payload[:path]}, c=#{payload[:controller]}, acn=#{payload[:action]}, h=#{payload[:server_ip]}, "\
     "sts=#{payload[:status]}, f=#{payload[:format]}, db=#{payload[:db_runtime]}, vw=#{payload[:view_runtime]}, rc=#{performance_metrics[:redis_calls]}, "\
     "r=#{performance_metrics[:redis_time].round(2)}, mc=#{performance_metrics[:memcache_calls]}, mdr=#{performance_metrics[:memcache_dup_reads]}, "\
     "m=#{performance_metrics[:memcache_time].round(2)}, oa=#{payload[:oa]}, qt=#{payload[:queue_time]}, tdur=#{payload[:total_duration]}, dur=#{payload[:duration]}"
  end
end

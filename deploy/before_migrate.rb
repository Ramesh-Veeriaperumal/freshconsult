shared_path = node[:opsworks] ? "/data/helpkit/shared" : config.shared_path
rel_path = node[:opsworks] ? "#{release_path}" : "#{config.release_path}"
puts ":::::::::::release path is ::: #{rel_path.inspect}"
run "ln -nfs #{shared_path}/config/memcached.yml #{rel_path}/config/memcached.yml"
run "ln -nfs #{shared_path}/config/database_cluster.yml  #{rel_path}/config/database.yml"
run "ln -nfs #{shared_path}/config/elasticsearch.yml  #{rel_path}/config/elasticsearch.yml"
run "ln -nfs #{shared_path}/config/redshift.yml  #{rel_path}/config/redshift.yml"
run "ln -nfs #{shared_path}/config/node_js.yml  #{rel_path}/config/node_js.yml"
run "ln -nfs #{shared_path}/config/gnip.yml  #{rel_path}/config/gnip.yml"
run "ln -nfs #{shared_path}/config/redis.yml #{rel_path}/config/redis.yml"
run "ln -nfs #{shared_path}/config/opsworks.yml #{rel_path}/config/opsworks.yml"
run "ln -nfs #{shared_path}/config/stats_redis.yml #{rel_path}/config/stats_redis.yml"
run "ln -nfs #{shared_path}/config/newrelic.yml #{rel_path}/config/newrelic.yml"
run "ln -nfs #{shared_path}/config/redis_mobile.yml #{rel_path}/config/redis_mobile.yml"
run "ln -nfs #{shared_path}/config/riak.yml #{rel_path}/config/riak.yml"
run "ln -nfs #{shared_path}/config/riak_buckets.yml #{rel_path}/config/riak_buckets.yml"
run "ln -nfs #{shared_path}/config/text_datastore.yml #{rel_path}/config/text_datastore.yml"
run "ln -nfs #{shared_path}/config/mailgun.yml #{rel_path}/config/mailgun.yml"
run "ln -nfs #{shared_path}/config/mailbox.yml #{rel_path}/config/mailbox.yml"
run "ln -nfs #{shared_path}/config/freshfone.yml #{rel_path}/config/freshfone.yml"
run "ln -nfs #{shared_path}/config/rate_limit.yml #{rel_path}/config/rate_limit.yml"
run "ln -nfs #{shared_path}/config/akismet.yml #{rel_path}/config/akismet.yml"
run "ln -nfs #{shared_path}/config/braintree.yml #{rel_path}/config/braintree.yml"
run "ln -nfs #{shared_path}/config/s3.yml #{rel_path}/config/s3.yml"

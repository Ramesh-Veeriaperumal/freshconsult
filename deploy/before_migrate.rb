shared_path = node[:opsworks] ? "/data/helpkit/shared" : config.shared_path
rel_path = node[:opsworks] ? "#{release_path}" : "#{config.release_path}"
puts ":::::::::::release path is ::: #{rel_path.inspect}"
run "ln -nfs #{shared_path}/config/database_cluster.yml  #{rel_path}/config/database.yml"
run "ln -nfs #{shared_path}/config/elasticsearch.yml  #{rel_path}/config/elasticsearch.yml"
run "ln -nfs #{shared_path}/config/redshift.yml  #{rel_path}/config/redshift.yml"
run "ln -nfs #{shared_path}/config/node_js.yml  #{rel_path}/config/node_js.yml"
run "ln -nfs #{shared_path}/config/gnip.yml  #{rel_path}/config/gnip.yml"
run "ln -nfs #{shared_path}/config/redis.yml #{rel_path}/config/redis.yml"
run "ln -nfs #{shared_path}/config/opsworks.yml #{rel_path}/config/opsworks.yml"
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
run "ln -nfs #{shared_path}/config/rabbitmq.yml #{rel_path}/config/rabbitmq.yml"
run "ln -nfs #{shared_path}/config/sidekiq.yml #{rel_path}/config/sidekiq.yml"
run "ln -nfs #{shared_path}/config/s3.yml #{rel_path}/config/s3.yml"
run "ln -nfs #{shared_path}/config/s3_static_files.yml #{rel_path}/config/s3_static_files.yml"
run "ln -nfs #{shared_path}/config/dalli.yml #{rel_path}/config/dalli.yml"
run "ln -nfs #{shared_path}/config/statsd.yml #{rel_path}/config/statsd.yml"
run "ln -nfs #{shared_path}/config/redis_display_id.yml #{rel_path}/config/redis_display_id.yml"
run "ln -nfs #{shared_path}/config/chat.yml #{rel_path}/config/chat.yml"
run "ln -nfs #{shared_path}/config/email.yml #{rel_path}/config/email.yml"
run "ln -nfs #{shared_path}/config/pod_info.yml #{rel_path}/config/pod_info.yml"
run "ln -nfs #{shared_path}/config/redis_routes.yml #{rel_path}/config/redis_routes.yml"
run "ln -nfs #{shared_path}/config/integrations_config.yml #{rel_path}/config/integrations_config.yml"
run "ln -nfs #{shared_path}/config/mobile_config.yml #{rel_path}/config/mobile_config.yml"
run "ln -nfs #{shared_path}/config/asset_sync.yml #{rel_path}/config/asset_sync.yml"
run "ln -nfs #{shared_path}/config/config.yml #{rel_path}/config/config.yml"
run "ln -nfs #{shared_path}/config/oauth_config.yml #{rel_path}/config/oauth_config.yml"
run "ln -nfs #{shared_path}/config/reports_app.yml #{rel_path}/config/helpdesk_reports/reports_app.yml"
run "ln -nfs #{shared_path}/config/marketplace.yml #{rel_path}/config/marketplace.yml"
# Xero Cert files start
run "ln -nfs #{shared_path}/config/cert/integrations/xero/entrust-cert.pem #{rel_path}/config/cert/integrations/xero/entrust-cert.pem"
run "ln -nfs #{shared_path}/config/cert/integrations/xero/entrust-private-nopass.pem #{rel_path}/config/cert/integrations/xero/entrust-private-nopass.pem"
run "ln -nfs #{shared_path}/config/cert/integrations/xero/privatekey.pem #{rel_path}/config/cert/integrations/xero/privatekey.pem"
run "ln -nfs #{shared_path}/config/cert/integrations/xero/publickey.cer #{rel_path}/config/cert/integrations/xero/publickey.cer"
# Xero Cert files end
# run "rsync --ignore-existing -razv /data/helpkit/current/public/assets #{rel_path}/public" if ::File.directory?("/data/helpkit/current") && ::File.directory?("/data/helpkit/current/public/assets")
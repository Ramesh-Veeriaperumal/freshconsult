shared_path = node[:opsworks] ? '/data/helpkit/shared' : config.shared_path
node.override[:rel_path] = node[:opsworks] ? release_path.to_s : config.release_path.to_s
puts ":::::::::::release path is ::: #{node[:rel_path]}"
puts ":::::::shared path is #{shared_path}"
run "ln -nfs #{shared_path}/config/announcements.yml  #{node[:rel_path]}/config/announcements.yml"
run "ln -nfs #{shared_path}/config/database_cluster.yml  #{node[:rel_path]}/config/database.yml"
run "ln -nfs #{shared_path}/config/elasticsearch.yml  #{node[:rel_path]}/config/elasticsearch.yml"
run "ln -nfs #{shared_path}/config/redshift.yml  #{node[:rel_path]}/config/redshift.yml"
run "ln -nfs #{shared_path}/config/node_js.yml  #{node[:rel_path]}/config/node_js.yml"
run "ln -nfs #{shared_path}/config/gnip.yml  #{node[:rel_path]}/config/gnip.yml"
run "ln -nfs #{shared_path}/config/facebook.yml  #{node[:rel_path]}/config/facebook.yml"
run "ln -nfs #{shared_path}/config/twitter.yml  #{node[:rel_path]}/config/twitter.yml"
run "ln -nfs #{shared_path}/config/redis.yml #{node[:rel_path]}/config/redis.yml"
run "ln -nfs #{shared_path}/config/opsworks.yml #{node[:rel_path]}/config/opsworks.yml"
run "ln -nfs #{shared_path}/config/newrelic.yml #{node[:rel_path]}/config/newrelic.yml"
run "ln -nfs #{shared_path}/config/redis_mobile.yml #{node[:rel_path]}/config/redis_mobile.yml"
run "ln -nfs #{shared_path}/config/mailgun.yml #{node[:rel_path]}/config/mailgun.yml"
run "ln -nfs #{shared_path}/config/mailbox.yml #{node[:rel_path]}/config/mailbox.yml"
run "ln -nfs #{shared_path}/config/freshfone.yml #{node[:rel_path]}/config/freshfone.yml"
run "ln -nfs #{shared_path}/config/freshcaller.yml #{node[:rel_path]}/config/freshcaller.yml"
run "ln -nfs #{shared_path}/config/rate_limit.yml #{node[:rel_path]}/config/rate_limit.yml"
run "ln -nfs #{shared_path}/config/re_route_mapping.yml #{node[:rel_path]}/config/re_route_mapping.yml"
run "ln -nfs #{shared_path}/config/akismet.yml #{node[:rel_path]}/config/akismet.yml"
run "ln -nfs #{shared_path}/config/braintree.yml #{node[:rel_path]}/config/braintree.yml"
run "ln -nfs #{shared_path}/config/rabbitmq.yml #{node[:rel_path]}/config/rabbitmq.yml"
run "ln -nfs #{shared_path}/config/sidekiq.yml #{node[:rel_path]}/config/sidekiq.yml"
run "ln -nfs #{shared_path}/config/shoryuken.yml #{node[:rel_path]}/config/shoryuken.yml"
run "ln -nfs #{shared_path}/config/s3.yml #{node[:rel_path]}/config/s3.yml"
run "ln -nfs #{shared_path}/config/cloud_front.yml #{node[:rel_path]}/config/cloud_front.yml"
run "ln -nfs #{shared_path}/config/sqs.yml #{node[:rel_path]}/config/sqs.yml"
run "ln -nfs #{shared_path}/config/aws_v2.yml #{node[:rel_path]}/config/aws_v2.yml"
run "ln -nfs #{shared_path}/config/s3_static_files.yml #{node[:rel_path]}/config/s3_static_files.yml"
run "ln -nfs #{shared_path}/config/dalli.yml #{node[:rel_path]}/config/dalli.yml"
run "ln -nfs #{shared_path}/config/dalli_api.yml #{node[:rel_path]}/config/dalli_api.yml"
run "ln -nfs #{shared_path}/config/custom_dalli.yml #{node[:rel_path]}/config/custom_dalli.yml"
run "ln -nfs #{shared_path}/config/redis_display_id.yml #{node[:rel_path]}/config/redis_display_id.yml"
run "ln -nfs #{shared_path}/config/chat.yml #{node[:rel_path]}/config/chat.yml"
run "ln -nfs #{shared_path}/config/collab.yml #{node[:rel_path]}/config/collab.yml"
run "ln -nfs #{shared_path}/config/email.yml #{node[:rel_path]}/config/email.yml"
run "ln -nfs #{shared_path}/config/pod_info.yml #{node[:rel_path]}/config/pod_info.yml"
run "ln -nfs #{shared_path}/config/redis_routes.yml #{node[:rel_path]}/config/redis_routes.yml"
run "ln -nfs #{shared_path}/config/integrations_config.yml #{node[:rel_path]}/config/integrations_config.yml"
run "ln -nfs #{shared_path}/config/freshpipe_configs.yml #{node[:rel_path]}/config/freshpipe_configs.yml"
run "ln -nfs #{shared_path}/config/fd_node_config.yml #{node[:rel_path]}/config/fd_node_config.yml"
run "ln -nfs #{shared_path}/config/mobile_config.yml #{node[:rel_path]}/config/mobile_config.yml"
run "ln -nfs #{shared_path}/config/asset_sync.yml #{node[:rel_path]}/config/asset_sync.yml"
run "ln -nfs #{shared_path}/config/config.yml #{node[:rel_path]}/config/config.yml"
run "ln -nfs #{shared_path}/config/oauth_config.yml #{node[:rel_path]}/config/oauth_config.yml"
run "ln -nfs #{shared_path}/config/reports_app.yml #{node[:rel_path]}/config/helpdesk_reports/reports_app.yml"
run "ln -nfs #{shared_path}/config/marketplace.yml #{node[:rel_path]}/config/marketplace.yml"
run "ln -nfs #{shared_path}/config/ecommerce.yml #{node[:rel_path]}/config/ecommerce.yml"
run "ln -nfs #{shared_path}/config/third_party_app_config.yml #{node[:rel_path]}/config/third_party_app_config.yml"
run "ln -nfs #{shared_path}/config/pod_dns_config.yml #{node[:rel_path]}/config/pod_dns_config.yml"
run "ln -nfs #{shared_path}/config/helpdesk.yml #{node[:rel_path]}/config/helpdesk.yml"
run "ln -nfs #{shared_path}/config/thrift.yml #{node[:rel_path]}/config/thrift.yml"
run "ln -nfs #{shared_path}/config/delayed_job_watcher.yml #{node[:rel_path]}/config/delayed_job_watcher.yml"
run "ln -nfs #{shared_path}/config/archive_note.yml #{node[:rel_path]}/config/archive_note.yml"
run "ln -nfs #{shared_path}/config/lambda.yml #{node[:rel_path]}/config/lambda.yml"
run "ln -nfs #{shared_path}/config/redis_round_robin.yml #{node[:rel_path]}/config/redis_round_robin.yml"
run "ln -nfs #{shared_path}/config/ml_app.yml #{node[:rel_path]}/config/ml_app.yml"
run "ln -nfs #{shared_path}/config/sendgrid_webhook_api.yml #{node[:rel_path]}/config/sendgrid_webhook_api.yml"
run "ln -nfs #{shared_path}/config/sds.yml #{node[:rel_path]}/config/sds.yml"
run "ln -nfs #{shared_path}/config/clamav.yml #{node[:rel_path]}/config/clamav.yml"
run "ln -nfs #{shared_path}/config/zendesk_app.yml #{node[:rel_path]}/config/zendesk_app.yml"
run "ln -nfs #{shared_path}/config/iris_notifications.yml #{node[:rel_path]}/config/iris_notifications.yml"
run "ln -nfs #{shared_path}/config/archive_queue.yml #{node[:rel_path]}/config/archive_queue.yml"
run "ln -nfs #{shared_path}/config/freshmarketer_automation.yml #{node[:rel_path]}/config/freshmarketer_automation.yml"
run "ln -nfs #{shared_path}/config/iam.yml #{node[:rel_path]}/config/iam.yml"
run "ln -nfs #{shared_path}/config/symmetric-encryption.yml #{node[:rel_path]}/config/symmetric-encryption.yml"
run "ln -nfs #{shared_path}/config/inline_manual.yml #{node[:rel_path]}/config/inline_manual.yml"
run "ln -nfs #{shared_path}/config/redis_session.yml #{node[:rel_path]}/config/redis_session.yml"
run "ln -nfs #{shared_path}/config/fd_email_service.yml #{node[:rel_path]}/config/fd_email_service.yml"
run "ln -nfs #{shared_path}/config/product_feedback.yml #{node[:rel_path]}/config/product_feedback.yml"
run "ln -nfs #{shared_path}/config/sidekiq_classification.yml #{node[:rel_path]}/config/sidekiq_classification.yml"
run "ln -nfs #{shared_path}/config/fdadmin_api_config.yml #{node[:rel_path]}/config/fdadmin_api_config.yml"
run "ln -nfs #{shared_path}/config/hashed_data.yml #{node[:rel_path]}/config/hashed_data.yml"
run "ln -nfs #{shared_path}/config/recaptcha_v2.yml #{node[:rel_path]}/config/recaptcha_v2.yml"
run "ln -nfs #{shared_path}/config/freshid.yml #{node[:rel_path]}/config/freshid.yml"
run "ln -nfs #{shared_path}/config/freshid_v2.yml #{node[:rel_path]}/config/freshid_v2.yml"
run "ln -nfs #{shared_path}/config/fluffy.yml #{node[:rel_path]}/config/fluffy.yml"
run "ln -nfs #{shared_path}/config/ner_api.yml #{node[:rel_path]}/config/ner_api.yml"
run "ln -nfs #{shared_path}/config/heap_analytics.yml #{node[:rel_path]}/config/heap_analytics.yml"
run "ln -nfs #{shared_path}/config/mailgun_out_going_email_mappings.yml #{node[:rel_path]}/config/mailgun_out_going_email_mappings.yml"
run "ln -nfs #{shared_path}/config/bot.yml #{node[:rel_path]}/config/bot.yml"
run "ln -nfs #{shared_path}/config/central.yml #{node[:rel_path]}/config/central.yml"
run "ln -nfs #{shared_path}/config/kafka_collector.yml #{node[:rel_path]}/config/kafka_collector.yml"
run "ln -nfs #{shared_path}/config/channel_framework.yml #{node[:rel_path]}/config/channel_framework.yml"
run "ln -nfs #{shared_path}/config/scheduler_client_keys.yml #{node[:rel_path]}/config/scheduler_client_keys.yml"
run "ln -nfs #{shared_path}/config/channel_api_keys.yml #{node[:rel_path]}/config/channel_api_keys.yml"
run "ln -nfs #{shared_path}/config/freshchat.yml #{node[:rel_path]}/config/freshchat.yml"
run "ln -nfs #{shared_path}/config/formserv.yml #{node[:rel_path]}/config/formserv.yml"
run "ln -nfs #{shared_path}/config/app_integration.yml #{node[:rel_path]}/config/app_integration.yml"
run "ln -nfs #{shared_path}/config/freshmarketer.yml #{node[:rel_path]}/config/freshmarketer.yml"
run "ln -nfs #{shared_path}/config/unsupported_features.yml #{node[:rel_path]}/config/features/unsupported_features.yml"
run "ln -nfs #{shared_path}/config/hyper_trail.yml #{node[:rel_path]}/config/hyper_trail.yml"
run "ln -nfs #{shared_path}/config/proactive_service.yml #{node[:rel_path]}/config/proactive_service.yml"
run "ln -nfs #{shared_path}/config/ocr_config.yml #{node[:rel_path]}/config/ocr_config.yml"
run "ln -nfs #{shared_path}/config/email_bot_ml_feedback_config.yml #{node[:rel_path]}/config/email_bot_ml_feedback_config.yml"
run "ln -nfs #{shared_path}/config/ask_nicely.yml #{node[:rel_path]}/config/ask_nicely.yml"
run "ln -nfs #{shared_path}/config/datadog.yml #{node[:rel_path]}/config/datadog.yml"
run "ln -nfs #{shared_path}/config/freshvisuals.yml #{node[:rel_path]}/config/helpdesk_reports/freshvisuals.yml"
run "ln -nfs #{shared_path}/config/freno.yml #{node[:rel_path]}/config/freno.yml"
run "ln -nfs #{shared_path}/config/automation_rule_redis.yml #{node[:rel_path]}/config/automation_rule_redis.yml"
run "ln -nfs #{shared_path}/config/freddy_skills_config.yml #{node[:rel_path]}/config/freddy_skills_config.yml"
run "ln -nfs #{shared_path}/config/facebook_gateway.yml #{node[:rel_path]}/config/facebook_gateway.yml"
run "ln -nfs #{shared_path}/config/cron_hooks.yml #{node[:rel_path]}/config/cron_hooks.yml"
run "ln -nfs #{shared_path}/config/shift_config.yml  #{node[:rel_path]}/config/shift_config.yml"
run "ln -nfs #{shared_path}/config/rts.yml #{node[:rel_path]}/config/rts.yml"
run "ln -nfs #{shared_path}/config/secure_field.yml #{node[:rel_path]}/config/jwe/secure_field.yml"
run "ln -nfs #{shared_path}/config/custom_survey_result_key.yml #{node[:rel_path]}/config/custom_survey_result_key.yml"
run "ln -nfs #{shared_path}/config/authz_config.yml #{node[:rel_path]}/config/authz_config.yml"
run "ln -nfs #{shared_path}/config/aloha_config.yml #{node[:rel_path]}/config/aloha_config.yml"
run "ln -nfs #{shared_path}/config/freshcaller_subscription_config.yml #{node[:rel_path]}/config/freshcaller_subscription_config.yml"
run "ln -nfs #{shared_path}/config/freshchat_subscription_config.yml #{node[:rel_path]}/config/freshchat_subscription_config.yml"
run "ln -nfs #{shared_path}/config/omni_freshvisuals.yml #{node[:rel_path]}/config/helpdesk_reports/omni_freshvisuals.yml"
run "ln -nfs #{shared_path}/config/channel_v2_api.yml #{node[:rel_path]}/config/channel_v2_api.yml"
run "ln -nfs #{shared_path}/config/silkroad_config.yml #{node[:rel_path]}/config/silkroad_config.yml"
run "ln -nfs #{shared_path}/config/omni_channel_dashboard.yml #{node[:rel_path]}/config/omni_channel_dashboard.yml"
run "ln -nfs #{shared_path}/config/omni_channel_bundle.yml #{node[:rel_path]}/config/omni_channel_bundle.yml"

# supreme-code-console
run "ln -nfs #{shared_path}/config/api_config_internal_tools.yml #{node[:rel_path]}/config/api_config_internal_tools.yml"
run "ln -nfs #{shared_path}/config/sandbox.yml  #{node[:rel_path]}/config/sandbox.yml"

# search V2
run "ln -nfs #{shared_path}/config/search/boost_values.yml #{node[:rel_path]}/config/search/boost_values.yml"
run "ln -nfs #{shared_path}/config/search/supported_types.yml #{node[:rel_path]}/config/search/supported_types.yml"
run "ln -nfs #{shared_path}/config/search/esv2_config.yml #{node[:rel_path]}/config/search/esv2_config.yml"
run "ln -nfs #{shared_path}/config/search/etl_queue.yml #{node[:rel_path]}/config/search/etl_queue.yml"
run "ln -nfs #{shared_path}/config/search/dynamo_tables.yml #{node[:rel_path]}/config/search/dynamo_tables.yml"

# Cert Files
run "ln -nfs #{shared_path}/config/cert/freshid.pem #{node[:rel_path]}/config/cert/freshid.pem"
run "ln -nfs #{shared_path}/config/cert/saml.pem #{node[:rel_path]}/config/cert/saml.pem"
run "ln -nfs #{shared_path}/config/cert/iam.pem #{node[:rel_path]}/config/cert/iam.pem"
run "ln -nfs #{shared_path}/config/cert/iam_public.pem #{node[:rel_path]}/config/cert/iam_public.pem"
run "ln -nfs #{shared_path}/config/cert/jwe_encryption_key.pem #{node[:rel_path]}/config/cert/jwe_encryption_key.pem"
run "ln -nfs #{shared_path}/config/cert/freddy_sessions.pem #{node[:rel_path]}/config/cert/freddy_sessions.pem"

# Xero Cert files start
run "ln -nfs #{shared_path}/config/cert/integrations/xero/entrust-cert.pem #{node[:rel_path]}/config/cert/integrations/xero/entrust-cert.pem"
run "ln -nfs #{shared_path}/config/cert/integrations/xero/entrust-private-nopass.pem #{node[:rel_path]}/config/cert/integrations/xero/entrust-private-nopass.pem"
run "ln -nfs #{shared_path}/config/cert/integrations/xero/privatekey.pem #{node[:rel_path]}/config/cert/integrations/xero/privatekey.pem"
run "ln -nfs #{shared_path}/config/cert/integrations/xero/publickey.cer #{node[:rel_path]}/config/cert/integrations/xero/publickey.cer"

# for copying previous files
run "rsync --ignore-existing -razv /data/helpkit/current/public/assets #{node[:rel_path]}/public" if ::File.directory?('/data/helpkit/current') && ::File.directory?('/data/helpkit/current/public/assets')

# for log sync
if ENV['SQUAD'] == '1'
  run "rm -rf #{node[:rel_path]}/log"
  run "ln -nsf #{shared_path}/log #{node[:rel_path]}"
end

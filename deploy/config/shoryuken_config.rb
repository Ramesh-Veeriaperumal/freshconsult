class ShoryukenConfig
  def self.setup(node, opsworks, options, in_templ, sidekiq_monitrc_templ)
    if node[:opsworks][:instance][:hostname].include?(node[:shoryuken][:hostname]) || opsworks.shoryuken_layer?() || opsworks.fc_shoryuken_layer?()
      puts "Generating Shoryuken worker configuration"

      # monit
      File.open("/etc/monit.d/bg/shoryuken_helpkit.monitrc", 'w') do |f|
        @app_name     = "helpkit"
        @workers      = node[:shoryuken][:workers]
        @environment = node[:opsworks][:environment]
        @memory_limit = 2048 # MB
        f.write(Erubis::Eruby.new(File.read(sidekiq_monitrc_templ)).result(binding))
      end

      node[:shoryuken][:workers].times do |count|
        out = File.join(options[:outdir], "shoryuken_#{count}.yml")
        puts "\tGenerating #{out}"
        File.open(out, 'w') do |f|
          @environment = node[:opsworks][:environment]
          @queues      = node[:shoryuken][:queues]
          @verbose     = node[:shoryuken][:verbose]
          @concurrency = opsworks.get_pool_size()
          @logfile     = "/data/helpkit/shared/log/shoryuken_#{count}.log"
          @pidfile     = "/data/helpkit/shared/pids/shoryuken_#{count}.pid"
          f.write(Erubis::Eruby.new(File.read(in_templ)).result(binding))
        end
      end
    end

    out = File.join(options[:outdir], "shoryuken.yml")
    puts "Generating shoryuken app configuration #{out}"
    File.open(out, 'w') do |f|
      @environment = node[:opsworks][:environment]
      @queues      = node[:shoryuken][:queues]
      @verbose     = node[:shoryuken][:verbose]
      @concurrency = opsworks.get_pool_size()
      @logfile     = "/data/helpkit/shared/log/shoryuken.log"
      @pidfile     = "/data/helpkit/shared/pids/shoryuken.pid"
      f.write(Erubis::Eruby.new(File.read(in_templ)).result(binding))
    end
  end

  def self.get_settings(node)
    hostname = node[:opsworks][:instance][:hostname]
    layers = Array::new()
    layers = node[:opsworks][:instance][:layers]
    shoruken_layer = layers.any? {|layer| layer.eql?(node[:falcon][:shoryuken][:layer])}

    common_pool_worker_count = (ENV['SQUAD'] == '1' && ENV['PRERUN'] != '1') || (node[:opsworks][:instance][:layers].count > 1) ? 2 : 8

    dedicated_execution = false

    settings = {}
    settings[:namespace]    = 'shoryuken'
    settings[:verbose]      = true       # Verbose
    settings[:queues]  =  {}

    if ENV["HELPKIT_TEST_SETUP_ENABLE"] == "1"
      rename_queues_for_test_setup(node)
    end

    if hostname.include?("shoryuken-archive")
      settings[:workers] = 6
      queue_category = node[:ymls][:shoryuken][:archive]
      queue_category.each do |queue_key, queue_config|
        settings[:queues][queue_config[:sqs_queue]] = queue_config[:priority]
      end
      dedicated_execution = true
    end

    if hostname.include?("shoryuken-maintenance")
      settings[:workers] = node[:cpu][:total]
      queue_category = node[:ymls][:shoryuken][:maintenance]
      queue_category.each do |queue_key, queue_config|
        settings[:queues][queue_config[:sqs_queue]] = queue_config[:priority]
      end
      dedicated_execution = true
    end

    case node[:ymls][:pods][:current_pod]
    when 'poduseast1' , 'poduseast'
      if hostname.include?("shoryuken-sidekiq-social")
        settings[:queues]["social_fb_feed_production"] = 1
        settings[:queues]["channel_framework_helpkit"] = 1
        settings[:workers] = 4
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-search")
        settings[:workers]      = 8
        settings[:queues]["search-etlqueue-production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-falcon-analytics")
        settings[:workers]      = 8
        settings[:queues]["analytics_etl_queue_production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-cluster1")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues]["cluster1-etlqueue-production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-cluster2")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues]["cluster2-etlqueue-production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-cluster3")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues]["cluster3-etlqueue-production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-archive-cluster1")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues]["cluster1-archive-etlqueue-production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-archive-cluster2")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues]["cluster2-archive-etlqueue-production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-archive-cluster3")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues]["cluster3-archive-etlqueue-production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-email-cluster") || hostname.include?("shoryuken-email-cluster")
        settings[:workers]      = 8
        settings[:queues]["free_customer_email_queue_production"] = 1
        settings[:queues]["active_customer_email_queue_production"] = 1
        settings[:queues]["trial_customer_email_queue_production"] = 1
        settings[:queues]["default_email_queue_production"] = 1
        settings[:queues]["failed_emails_queue_production"] = 1
        settings[:queues]["custom_mailbox_notification"] = 1
        settings[:queues]['email_rate_limiting_production'] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-ticket-export") || hostname.include?("shoryuken-ticket-export")
        settings[:workers]      = 3
        settings[:queues]["scheduled_ticket_export_complete_production"] = 1
        settings[:queues]["scheduled_export_payload_enricher_queue_production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-facebook-migration")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues]["facebook_migration_queue_production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-falcon-scheduler") || hostname.include?("shoryuken-falcon-scheduler")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues]["fd_scheduler_reminder_todo_queue_production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-falcon-social") || hostname.include?("shoryuken-falcon-social")
        settings[:workers]      = 4
        settings[:queues]["social_gnip_2_0_tweet_production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-bot-feedback") || hostname.include?("shoryuken-bot-feedback")
        settings[:workers]                           = node[:cpu][:total]
        settings[:queues]["bot_feedback_production"] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-export-cleanup")
        settings[:workers]                           = node[:cpu][:total]
        settings[:queues]["fd_scheduler_export_cleanup_queue_production"] = 1
        dedicated_execution = true
      end

      unless dedicated_execution
        settings[:workers] = common_pool_worker_count
        queue_category = shoruken_layer ? node[:ymls][:shoryuken][:falcon] : node[:ymls][:shoryuken][:queue_config]
        queue_category.each do |queue_key, queue_config|
          settings[:queues][queue_config[:sqs_queue]] = queue_config[:priority]
        end
      end
    else
      settings[:verbose]      = true       # Verbose
      settings[:namespace]    = 'shoryuken'

      unless dedicated_execution
        settings[:workers]      = 8        # Number of worker processes (not threads)
        queue_category = shoruken_layer ? node[:ymls][:shoryuken][:falcon] : node[:ymls][:shoryuken][:queue_config]
        queue_category.each do |queue_key, queue_config|
          settings[:queues][queue_config[:sqs_queue]] = queue_config[:priority]
        end
      end
    end


    return settings
  end

  def self.rename_queues_for_test_setup(node)
    STDERR.puts "Shoryuken: Renaming SQS queues for test setup"

    queues_keys_to_rename = [
      :scheduled_export_payload,
      :scheduled_ticket_export,
      :search_etlqueue,
      :cluster1_archive,
      :cluster_etlqueue,
      :social_gnip_tweets,
      :active_email,
      :bot_feedback_queue,
      :channel_framework_services,
      :custom_mailbox_status,
      :default_email,
      :email_failure_reference,
      :failed_emails,
      :free_email,
      :social_fb_feed,
      :trial_email,
      :fd_scheduler_export_cleanup_queue,
      :analytics_etl_queue,
      :freddy_consumed_session_reminder_queue,
      :email_rate_limiting_queue,
      :switch_to_annual_notification,
      :downgrade_policy_reminder
    ]

    queue_prefix = ENV["HELPKIT_TEST_SETUP_SQS_QUEUE_PREFIX"]
    if !queue_prefix or queue_prefix == ""
      STDERR.puts "Error: HELPKIT_TEST_SETUP_SQS_QUEUE_PREFIX env variable is not set"
      exit 1
    end

    node[:ymls][:shoryuken][:falcon].keys.each { |k|
      if queues_keys_to_rename.include?(k)
        new_name = queue_prefix + "_" + k.to_s
        STDERR.puts("\tFor key '#{k}', renaming '#{node[:ymls][:shoryuken][:falcon][k][:sqs_queue]}' to '#{new_name}'")
        node[:ymls][:shoryuken][:falcon][k][:sqs_queue] = new_name
      end
    }

    node[:ymls][:shoryuken][:queue_config].keys.each { |k|
      if queues_keys_to_rename.include?(k)
        new_name = queue_prefix + "_" + k.to_s
        STDERR.puts("\tFor key '#{k}', renaming '#{node[:ymls][:shoryuken][:queue_config][k][:sqs_queue]}' to '#{new_name}'")
        node[:ymls][:shoryuken][:queue_config][k][:sqs_queue] = new_name
      end
    }

    STDERR.puts "\n\tQueues after rename: #{node[:ymls][:shoryuken].inspect}"
  end
end

class ShoryukenConfig
  def self.setup(node, opsworks, options, in_templ)
    if node[:opsworks][:instance][:hostname].include?(node[:shoryuken][:hostname]) || opsworks.shoryuken_layer?() || opsworks.fc_shoryuken_layer?()
      puts "Generating Shoryuken worker configuration"
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

    dedicated_execution = false

    settings = {}
    settings[:namespace]    = 'shoryuken'
    settings[:verbose]      = true       # Verbose
    settings[:queues]  =  {}

    case node[:ymls][:pods][:current_pod]
    when 'poduseast1' , 'poduseast'
      if hostname.include?("shoryuken-sidekiq-social")
        settings[:queues][:social_fb_feed_production] = 1
        settings[:queues][:channel_framework_helpkit] = 1
        settings[:workers]
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-search")
        settings[:workers]      = 8
        settings[:queues][:search-etlqueue-production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-count")
        settings[:workers]      = 6
        settings[:queues][:count_etl_queue_production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-cluster1")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues][:cluster1-etlqueue-production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-cluster2")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues][:cluster2-etlqueue-production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-cluster3")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues][:cluster3-etlqueue-production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-archive-cluster1")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues][:cluster1-archive-etlqueue-production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-archive-cluster2")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues][:cluster2-archive-etlqueue-production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-archive-cluster3")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues][:cluster3-archive-etlqueue-production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-email-cluster")
        settings[:workers]      = 8
        settings[:queues][:free_customer_email_queue_production] = 1
        settings[:queues][:active_customer_email_queue_production] = 1
        settings[:queues][:trial_customer_email_queue_production] = 1
        settings[:queues][:default_email_queue_production] = 1
        settings[:queues][:failed_emails_queue_production] = 1
        settings[:queues][:custom_mailbox_notification] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-ticket-export")
        settings[:workers]      = 3
        settings[:queues][:scheduled_ticket_export_complete_production] = 1
        settings[:queues][:scheduled_export_payload_enricher_queue_production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-facebook-migration")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues][:facebook_migration_queue_production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-falcon-scheduler")
        settings[:workers]      = node[:cpu][:total]
        settings[:queues][:fd_scheduler_reminder_todo_queue_production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-falcon-social")
        settings[:workers]      = 4
        settings[:queues][:social_gnip_2_0_tweet_production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-bot-feedback")
        settings[:workers]                           = node[:cpu][:total]
        settings[:queues][:bot_feedback_production] = 1
        dedicated_execution = true
      end

      if hostname.include?("shoryuken-sidekiq-export-cleanup")
        settings[:workers]                           = node[:cpu][:total]
        settings[:queues][:fd_scheduler_export_cleanup_queue_production] = 1
        dedicated_execution = true
      end

      unless dedicated_execution
        settings[:workers] = 2
        queue_category = shoruken_layer ? node[:ymls][:shoryuken][:falcon] : node[:ymls][:shoryuken][:queue_config]
        queue_category.each do |queue_key, queue_config|
          settings[:queues][queue_config[:sqs_queue]] = queue_config[:priority]
        end
      end
    else
      settings[:verbose]      = true       # Verbose
      settings[:namespace]    = 'shoryuken'
      unless dedicated_execution
        settings[:workers]      = 4        # Number of worker processes (not threads) 
        queue_category = shoruken_layer ? node[:ymls][:shoryuken][:falcon] : node[:ymls][:shoryuken][:queue_config]
        queue_category.each do |queue_key, queue_config|
          settings[:queues][queue_config[:sqs_queue]] = queue_config[:priority]
        end
      end
    end

    return settings
  end
end

# Based on helpkit_recipes/blob/shell-master/sidekiq/recipes/

class SidekiqConfig
  def self.getsettings
    settings = {}
    settings[:utility_name] = 'sidekiq'

    settings[:redis_pool_size] = 25
    settings[:verbose]      = true # Verbose
    settings[:namespace]    = 'sidekiq'
    # include_attribute 'redis'
    # include_attribute 'global::default'

    return settings
  end

  def self.setup(node, opsworks, options, sidekiq_in_templ, sidekiq_monitrc_templ)
    SidekiqConfigStandard.setup(node, opsworks, options, sidekiq_in_templ, sidekiq_monitrc_templ)
  end
end

class SidekiqConfigStandard
  COMMON_SIDEKIQ           = 'sidekiq-common-'.freeze
  REALTIME_SIDEKIQ         = 'sidekiq-realtime-'.freeze
  CENTRAL_REALTIME_SIDEKIQ = 'sidekiq-central-realtime-'.freeze

  # new classifications
  OCCASIONAL_SIDEKIQ       = 'sidekiq-occasional-'.freeze
  FREQUENT_SIDEKIQ         = 'sidekiq-frequent-'.freeze
  MAINTENANCE_SIDEKIQ      = 'sidekiq-maintenance-'.freeze
  ARCHIVE_SIDEKIQ          = 'sidekiq-archive-'.freeze
  EXTERNAL_SIDEKIQ         = 'sidekiq-external-'.freeze
  LONG_RUNNING             = 'sidekiq-longrunning-'.freeze
  DATAEXPORT_SIDEKIQ       = 'sidekiq-dataexport-'.freeze

  def self.get_pool(node)
    utility_name = node[:opsworks][:instance][:hostname]

    # This change is specifically for staging environment to overcome the memory issue.
    common_pool_worker_count = node[:opsworks][:instance][:layers].count > 1 ? 4 : 7

    all_sidekiq_jobs = ['common', 'realtime', 'central_realtime', 'frequent', 'external', 'occasional', 'maintenance']
    # falcon common sidekiq
    realtime                 = ['realtime']
    central_realtime         = ['central_realtime']

    # new classification
    occasional               = ['occasional']
    frequent                 = ['frequent']
    maintenance              = ['maintenance']
    archive                  = ['common', 'central_realtime']
    external                 = ['external']
    long_running             = ['long_running']
    account_data_export      = ['data_export']

    common_pool              = [[all_sidekiq_jobs, common_pool_worker_count]]

    realtime_pool            = [[realtime, 6]]
    central_realtime_pool    = [[central_realtime, 6]]

    # new classification
    occasional_pool          = [[occasional, 6]]
    frequent_pool            = [[frequent, 6]]
    maintenance_pool         = [[maintenance, 4]]
    archive_pool             = [[archive, 6]]
    external_pool            = [[external, 6]]
    longrunning_pool         = [[long_running, 6]]
    dataexport_pool          = [[account_data_export, 6]]

    case
    when utility_name.include?(REALTIME_SIDEKIQ)
      realtime_pool
    when utility_name.include?(CENTRAL_REALTIME_SIDEKIQ)
      central_realtime_pool
    # new classification
    when utility_name.include?(OCCASIONAL_SIDEKIQ)
      occasional_pool
    when utility_name.include?(FREQUENT_SIDEKIQ)
      frequent_pool
    when utility_name.include?(MAINTENANCE_SIDEKIQ)
      maintenance_pool
    when utility_name.include?(ARCHIVE_SIDEKIQ)
      archive_pool
    when utility_name.include?(EXTERNAL_SIDEKIQ)
      external_pool
    when utility_name.include?(LONG_RUNNING)
      longrunning_pool
    when utility_name.include?(DATAEXPORT_SIDEKIQ)
      dataexport_pool
    # when utility_name.include?(FALCON_COMMON_SIDEKIQ)
    #   FALCON_COMMON_POOL
    when utility_name.include?(COMMON_SIDEKIQ)
      common_pool
    else
      common_pool
    end
  end

  def self.setup(node, opsworks, options, sidekiq_in_templ, sidekiq_monitrc_templ)
    puts 'Setting up standard sidekiq'

    pool = get_pool(node)
    queues = queue_priorities(pool)

    puts "Queues in this instance: #{queues.inspect}"

    worker_count = queues.size

    # bin script
    # /usr/bin/sidekiq_wrapper is part of docker itself

    # monit
    File.open('/etc/monit.d/bg/sidekiq_helpkit.monitrc', 'w') do |f|
      @app_name     = 'helpkit'
      @workers      = worker_count
      @environment = node[:opsworks][:environment]
      @memory_limit = node[:sidekiq][:memory] || 3072 # MB
      f.write(Erubis::Eruby.new(File.read(sidekiq_monitrc_templ)).result(binding))
    end

    # yml files
    worker_count.times do |count|
      out = File.join(options[:outdir], "sidekiq_client_#{count}.yml")
      File.open(out, 'w') do |f|
        @environment = node[:opsworks][:environment]
        @queues      = queues[count]
        @verbose     = node[:sidekiq][:verbose]
        @redis_pool_size = node[:sidekiq][:redis_pool_size]
        @concurrency = opsworks.get_pool_size
        @logfile     = "/data/helpkit/shared/log/sidekiq_#{count}.log"
        @pidfile     = "/data/helpkit/shared/pids/sidekiq_#{count}.pid"
        f.write(Erubis::Eruby.new(File.read(sidekiq_in_templ)).result(binding))
      end
    end
  end

  def self.queue_priorities(pool_name)
    queue_priorities = []
    pool_name.each do |queue_def|
      queue_def[1].times { |name| queue_priorities << queue_def[0] }
    end
    queue_priorities
  end
end

# Based on helpkit_recipes/blob/shell-master/resque/recipes/

class ResqueConfig
  def self.get_settings(node)
    settings = {}
    return settings
  end

  def self.setup(node, opsworks, options, erb_in_dir)
    ResqueStandard::setup(node, opsworks, options, erb_in_dir)
  end
end

class ResqueStandard

  freshfone_realtime_queues = 'freshfone_notification_recovery_queue,freshfone_default_queue,freshfone_queue_wait,freshfone_attachment_queue,data_export_queue'

  FRESHFONE_POOL = [[freshfone_realtime_queues,5]]

  def self.get_queue_list
    queue_priorities = []
    FRESHFONE_POOL.each do |worker_pool|
      worker_pool[1].times {|name| queue_priorities << worker_pool[0]} 
    end
    queue_priorities
  end

  def self.setup(node, opsworks, options, erb_in_dir)

    queues = get_queue_list

    worker_count = queues.size

    File.open("/etc/monit.d/bg/resque_helpkit.monitrc", 'w') do |f|
      @num_workers = worker_count
      @app_name = "helpkit"
      @rails_env = node[:opsworks][:environment]
      f.write(Erubis::Eruby.new(File.read(File.join(erb_in_dir,"resque.monitrc.erb"))).result(binding))
    end

    worker_count.times do |count|
      
      File.open(File.join(options[:outdir], "resque_#{count}.conf"), 'w') do |f|
        @queue_priority = queues[count]
        f.write(Erubis::Eruby.new(File.read(File.join(erb_in_dir,"resque.conf.erb"))).result(binding))
      end
    end

    File.open("/etc/monit.d/bg/resque_scheduler_helpkit.monitrc", 'w') do |f|
      @rails_env = node[:opsworks][:environment]
      @app_name     = "helpkit"
      f.write(Erubis::Eruby.new(File.read(File.join(erb_in_dir,"resque-scheduler.monitrc.erb"))).result(binding))
    end
  end
  
end

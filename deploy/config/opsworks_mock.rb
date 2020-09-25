class Node < Hash
  def initialize(options, settings)
    @options = options
    @settings = settings

    self[:opsworks] = {}
    self[:opsworks][:environment] = @options[:environment]
    self[:ymls] = @settings[:ymls]
    self[:unique_keys] = @settings[:unique_keys]
    self[:opsworks_access_keys] = @settings[:opsworks_access_keys]

    self[:opsworks][:instance] = {}
    self[:opsworks][:instance][:layers] = [ @options[:layer] ]
    self[:opsworks][:instance][:hostname] = @options[:hostname]
    self[:opsworks][:instance][:private_ip] = @options[:private_ip]
    self[:opsworks][:account_id] = @settings[:opsworks][:account_id]
    self[:opsworks][:stack] = { :name => @options[:stackname] }

    self[:falcon_ui] = @settings[:falcon_ui]

    self[:aws_config] = @settings[:aws_config]
    self[:stack_config] = @settings[:stack_config]
    self[:config_gen] = @settings[:config_gen]

    self[:yml_search] = [ "esv2_config.yml.erb", "boost_values.yml.erb", "dynamo_tables.yml.erb", "etl_queue.yml.erb", "supported_types.yml.erb" ]

    self[:xero] = @settings[:xero]
    self[:xero][:cert_names] = ["entrust-cert.pem","entrust-private-nopass.pem","privatekey.pem","publickey.cer"]
    self[:common_certs] = @settings[:common_certs]

    self[:sandbox_host] = "git-codecommit.*.amazonaws.com"
    self[:sandbox_files] = ["codecommit_rsa.pub","codecommit_rsa"]

    self[:newrelic] = @settings[:newrelic]

    self[:docker] = @settings[:docker]

    self[:proxysql] = @settings[:proxysql]

    self[:cpu] = {
      :total => self.get_cpu_count()
    }

    self[:helpkit] = {
      :app => {
        :prefix => "hk-app",
        :reports => { :prefix => "hk-app-reports" }
      },
      :bg => {
        :prefix => "hk-bg"
      },
      :utility => {
        :prefix =>  "hk-bg-utility"
      },
      :pipeline => {
        :prefix => "hk-app-pipeline"
      },
      :support => {
        :prefix =>  "hk-app-support"
      },
      :mobihelp => {
        :prefix =>  "hk-app-mobihelp"
      },
      :shoryuken => {
        :layer => "hk-bg-shoryuken"
      }
    }

    self[:falcon] = {
      :app => {
        :prefix => "fc-app",
        :reports => { :prefix => "fc-app-reports" },
        :freshid => { :prefix => "fc-app-freshid" }
      },
      :bg => {
        :prefix => "fc-bg"
      },
      :utility => {
        :prefix =>  "fc-bg-utility"
      },
      :sidekiq => {
        :prefix =>  "fc-bg-sidekiq",
        :archive => { :layer => "fc-bg-sidekiq-archive" }
      },
      :api => {
        :prefix => "fc-app-api",
        :public => { :prefix => "fc-app-api-public" },
        :channel => { :prefix => "fc-app-api-channel" }
      },
      :resque => {
        :prefix =>  "resque"
      },
      :shoryuken => {
        :layer =>  "fc-bg-shoryuken"
      },
      :pipeline => {
        :prefix => "fc-app-pipeline"
      }
    }

    self[:shoryuken] = @settings[:shoryuken].deep_merge(ShoryukenConfig::get_settings(self))

    self[:sidekiq] = SidekiqConfig.getsettings
  end

  def get_cpu_count
    count = nil

    # Handle cpu count properly. We need to support the following
    # environments
    #
    # 1. K8s environment
    # 2. Dockerized environement without k8s
    # 3. Non-dockerized / standalone environment
    #
    # For 1: We will look for POD_CPU_REQUEST env value. Note that
    #        "/sys/fs/cgroup/cpuset/cpuset.cpus" cannot be used in k8s,
    #        since all host CPUs will be exposed to each container. k8s
    #        relies on "cpu quota" for limiting CPU usage.
    #
    #        For k8s alone, we will return 1.5 times of this value, we will
    #        overcommit for better utilization
    #
    # For 2: We will read from "/sys/fs/cgroup/cpuset/cpuset.cpus"
    #
    # For 3: We will read from "/proc/cpuinfo"
    #
    if ! ENV["POD_CPU_REQUEST"].nil?
      available = ENV["POD_CPU_REQUEST"].to_f
      if available < 1.0
        available = 1
      end

      count = (available * 1.5).ceil
    elsif File.readable?("/sys/fs/cgroup/cpuset/cpuset.cpus")
      # Handle dockerized environment correctly
      count = 0
      cpuset = IO.read("/sys/fs/cgroup/cpuset/cpuset.cpus").strip()
      cpuset.split(",").each { |g|
        ids = g.split("-")
        if ids.length == 2
          count += ids[1].to_i - ids[0].to_i + 1
        else
          count += 1
        end
      }
    end

    if count.nil?
      if File.readable?("/proc/cpuinfo")
        count = IO.read("/proc/cpuinfo").scan(/^processor/).size
      end
    end

    raise "Can't find cpu count" if count.nil?

    return count
  end
end

class OpsWorks
  def initialize(node, options)
    @node = node
    @options = options
  end

  def migration_layer?()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? { |layer| layer.include?("db-migration") }
  end

  def app_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:helpkit][:app][:prefix]) || layer.include?(@node[:falcon][:app][:prefix])}
  end

  def hk_app_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:helpkit][:app][:prefix])}
  end

  def fc_app_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:falcon][:app][:prefix])}
  end

  def bg_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:helpkit][:bg][:prefix]) || layer.include?(@node[:falcon][:bg][:prefix])}
  end

  def hk_bg_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:helpkit][:bg][:prefix])}
  end

  def fc_bg_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:falcon][:bg][:prefix])}
  end

  def fc_layer?()
    fc_bg_layer?() || fc_app_layer?()
  end

  def hk_layer?()
    hk_app_layer?() || hk_bg_layer?()
  end

  def sidekiq_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:falcon][:sidekiq][:prefix])}
  end

  def sidekiq_archive_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:falcon][:sidekiq][:archive][:layer])}
  end

  def maintenance_redis_enabled?()
    is_buffer_shell = get_shell().eql?("buffer")
    maintenance_redis_enabled = @node[:ymls][:sidekiq][:maintenance_host].present? && @node[:ymls][:sidekiq][:maintenance_port].present? && @node[:ymls][:sidekiq][:maintenance_password].present?
    return is_buffer_shell && maintenance_redis_enabled
  end

  def shoryuken_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:helpkit][:shoryuken][:layer])}
  end

  def fc_shoryuken_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:falcon][:shoryuken][:layer])}
  end

  # Checks for exact name
  def resque_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:falcon][:resque][:prefix])}
  end

  def utility_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:helpkit][:utility][:prefix])}
  end

  def fc_api_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:falcon][:api][:prefix])}
  end

  def fc_api_public_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:falcon][:api][:public][:prefix])}
  end

  def fc_api_channel_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:falcon][:api][:channel][:prefix])}
  end

  def fc_frontend?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?('fc-frontend') || layer.include?('falcon_frontend')}
  end

  def pipeline_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? { |layer| layer.include?(@node[:falcon][:pipeline][:prefix]) || layer.include?(@node[:helpkit][:pipeline][:prefix]) }
  end

  def support_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:helpkit][:support][:prefix]) || layer.include?(@node[:helpkit][:mobihelp][:prefix])}
  end

  def freshid_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:falcon][:app][:freshid][:prefix])}
  end

  def reports_layer?()
    layers = Array::new()
    layers = @node[:opsworks][:instance][:layers]
    layers.any? {|layer| layer.include?(@node[:helpkit][:app][:reports][:prefix]) || layer.include?(@node[:falcon][:app][:reports][:prefix])}
  end


  def production?()
    @node[:opsworks][:environment].include?('production')
  end

  def staging?()
    @node[:opsworks][:environment].include?('staging')
  end

  def get_shell()
    stack = @node[:opsworks][:stack][:name]
    if stack.end_with? "services"
      "services"
    else
      stack.split("-")[-2]
    end
  end

  def get_color()
    stack = @node[:opsworks][:stack][:name]
    stack.split("-")[-1]
  end

  def get_pod()
    stack = @node[:opsworks][:stack][:name]
    stack.split("-")[0]
  end

  def get_pool_size()
    layer_name = @options[:layer]
    if @node[:config_gen][:pool_size][:dedicated] && @node[:config_gen][:pool_size][:dedicated][layer_name.to_sym]
      concurrency = @node[:config_gen][:pool_size][:dedicated][layer_name.to_sym]

    elsif @node[:config_gen][:pool_size][:default]
      if layer_name.include? "sidekiq"
        concurrency = @node[:config_gen][:pool_size][:default][:sidekiq]
      elsif layer_name.include? "shoryuken"
        concurrency = @node[:config_gen][:pool_size][:default][:shoryuken]
      elsif  app_layer?()
        concurrency = @node[:config_gen][:pool_size][:default][:app]
      else
        concurrency = @node[:config_gen][:pool_size][:default][:others]
      end
    end

    return concurrency
  end
end

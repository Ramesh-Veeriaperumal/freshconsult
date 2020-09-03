#!/usr/bin/env ruby

require 'optparse'
require 'json'
require 'yaml'
require 'fileutils'

folder = File.expand_path('.',__dir__)
$:.unshift(folder) unless $:.include?(folder)
require 'sidekiq_config.rb'
require 'resque_config.rb'
require 'shoryuken_config.rb'
require 'opsworks_mock.rb'

module HelpkitDynamicConfig
  def self.init()
    @options = {}

    subtext=<<HEREDOC

        generate_config              : Generate config files from ERB templates
        encrypt                      : Encrypt the ejson file
        decrypt                      : Decrypt the ejson file
        generate                     : Generate base ejson file
        validate                     : Validate ejson, check if secrets are encrypted
        prepare_ejson                : This takes json and converts it to ejson format (by prefixing non-secrets with "_" etc)
        generate_ejson_from_opsworks : Generate ejson from OpsWorks stack/layer settings

Examples:

        # To generate YML config files from the ERB template
        ./deploy/config/dynamic_config_util.rb generate_config --region us-east-1 --environment staging --layer hk-app --hostname hk-app-1 --file ./deploy/config/settings-staging-us-east-1.ejson --outdir /tmp/config  --indir ./deploy/config/erb --kms --stackname fd-staging-green --infra_secrets staging_secret --private_ip 172.16.1.1 --override_ejson ./deploy/override/app-override-settings.ejson --override_json ./deploy/override/app-override-settings.json
        # To encrypt the ejson file
        ./deploy/config/dynamic_config_util.rb encrypt --file ./deploy/config/settings-staging-us-east-1.ejson

        # To decrypt the ejson file using KMS, display it on screen
        ./deploy/config/dynamic_config_util.rb decrypt --layer hk-app --kms --file ./deploy/config/settings-staging-us-east-1.ejson

        # To generate complete ejson file from OpsWorks stack and layer settings
        ./deploy/config/dynamic_config_util.rb generate_ejson_from_opsworks --stackid "93a948dc-888a-4da7-b6fc-8b6a2e9d6799" --region us-east-1 --file ./deploy/config/settings-staging-us-east-1.ejson --kms "c3a61a81-1a93-48ce-8e60-d4adb8acc31e"
HEREDOC

    global = OptionParser.new do |opts|
      opts.banner = "\nA utility to manage app configuration. This can be used to store encrypted secrets, to decrypt the secrets etc\n\n"
      opts.banner = opts.banner + "Usage: #{__FILE__} [subcommand [options]]"
      opts.separator ""
      opts.separator subtext
      opts.separator ""
    end

    subcommands = {
      'generate_config' => OptionParser.new do |opts|
        opts.banner = "Usage: generate_config [options]"
        opts.on('-r', '--region=REGION', 'Region where app is currently running') { |v| @options[:region] = v }
        opts.on('-e', '--environment=APP_ENV', 'Application environment: staging or production') { |v| @options[:environment] = v }
        opts.on('-l', '--layer=LAYER', 'Layer this app belongs to') { |v| @options[:layer] = v }
        opts.on('-h', '--hostname=HOSTNAME', 'Host name of the app') { |v| @options[:hostname] = v }
        opts.on('-o', '--outdir=OUPUTDIR', 'Output directory where generated config files will be written to') { |v| @options[:outdir] = v }
        opts.on('-f', '--file=SETTINGS.EJSON', 'Input settings ejson file') { |v| @options[:file] = v }
        opts.on('-i', '--indir=ERBDIR', 'ERB directory location') { |v| @options[:indir] = v }
        opts.on('-k', '--kms', 'Use KMS to decrypt the ejson') { |v| @options[:kms] = true }
        opts.on('-n', '--stackname=STACKNAME', 'OpsWorks Stack name') { |v| @options[:stackname] = v }
        opts.on('-p', '--private-ip=ip', 'Host private IP') { |v| @options[:private_ip] = v }
        opts.on('-j', '--override_json=OVERRIDE_JSON', 'Override Input Settings') { |v| @options[:override_json] = v }
        opts.on('-x', '--override_ejson=OVERRIDE_EJSON', 'Override Input Settings EJSON') { |v| @options[:override_ejson] = v }
        opts.on('-s', '--infra_secrets=INFRA_SECRETS', 'Infra Secrets Name') { |v| @options[:infra_secrets] = v }
      end,
      'generate_falcon_assets' => OptionParser.new do |opts|
        opts.banner = "Usage: generate_falcon_assets [options]"
        opts.on('-r', '--region=REGION', 'Region where app is currently running') { |v| @options[:region] = v }
        opts.on('-e', '--environment=APP_ENV', 'Application environment: staging or production') { |v| @options[:environment] = v }
        opts.on('-f', '--file=SETTINGS.EJSON', 'Input settings ejson file') { |v| @options[:file] = v }
        opts.on('-x', '--override_ejson=OVERRIDE_EJSON', 'Override Input Settings EJSON') { |v| @options[:override_ejson] = v }
        opts.on('-s', '--infra_secrets=INFRA_SECRETS', 'Infra Secrets Name') { |v| @options[:infra_secrets] = v }
        opts.on('-k', '--kms', 'Use KMS to decrypt the ejson') { |v| @options[:kms] = true }
        opts.on('-l', '--layer=LAYER', 'Layer this app belongs to') { |v| @options[:layer] = v }
        opts.on('-n', '--stackname=STACKNAME', 'OpsWorks Stack name') { |v| @options[:stackname] = v }
        opts.on('-h', '--hostname=HOSTNAME', 'Host name of the app') { |v| @options[:hostname] = v }
        opts.on('-v', '--revision=EMBER_REVISION', 'Host name of the app') { |v| @options[:revision] = v }
      end,
      'decrypt' => OptionParser.new do |opts|
        opts.banner = "Usage: decrypt [options]\n One of --kms or --private_key should be provided"
        opts.on('-f', '--file=SETTINGS.EJSON', 'Input settings ejson file') { |v| @options[:file] = v }
        opts.on('-p', '--private_key_dir=DIR', 'Private key directory') { |v| @options[:private_key_dir] = v }
        opts.on('-k', '--kms', 'Use KMS to decrypt the ejson') { |v| @options[:kms] = true }
        opts.on('-r', '--region=REGION', 'Region where app is currently running') { |v| @options[:region] = v }
        opts.on('-l', '--layer=LAYER', 'Layer this app belongs to') { |v| @options[:layer] = v }
        opts.on('-n', '--stackname=STACKNAME', 'OpsWorks Stack name') { |v| @options[:stackname] = v }
      end,
      'encrypt' => OptionParser.new do |opts|
        opts.banner = "Usage: encrypt [options]"
        opts.on('-f', '--file=SETTINGS.EJSON', 'Settings ejson file to encrypt/update in-place') { |v| @options[:file] = v }
      end,
      'generate' => OptionParser.new do |opts|
        opts.banner = "Usage: generate [options]\n One of --kms or --private_key should be provided"
        opts.on('-f', '--file=SETTINGS.EJSON', 'Settings ejson file to write to. This will be OVERWRITTEN') { |v| @options[:file] = v }
        opts.on('-k', '--kms=KMS_KEY_ID', 'Private key will be stored within the ejson, encrypted with KMS') { |v| @options[:kms] = v }
        opts.on('-p', '--private_key_dir=DIR', 'Private key directory') { |v| @options[:private_key_dir] = v }
        opts.on('-r', '--region=REGION', 'Region. Mandatory for --kms option') { |v| @options[:region] = v }
      end,
      'validate' => OptionParser.new do |opts|
        opts.banner = "Usage: validate [options]"
        opts.on('-f', '--file=SETTINGS.EJSON', 'Settings ejson file to validate') { |v| @options[:file] = v }
      end,
      'prepare_ejson' => OptionParser.new do |opts|
        opts.banner = "Usage: prepare_ejson [options]\n"
        opts.on('-f', '--file=SETTINGS.EJSON', 'json file to convert to ejson (updated in place)') { |v| @options[:file] = v }
      end,
      'generate_ejson_from_opsworks' => OptionParser.new do |opts|
        opts.banner = "Usage: generate_ejson_from_opsworks [options]\n"
        opts.on('-f', '--file=SETTINGS.EJSON', 'Settings ejson file to write to') { |v| @options[:file] = v }
        opts.on('-r', '--region=REGION', 'AWS Region') { |v| @options[:region] = v }
        opts.on('-r', '--api_endpoint=API_ENDPOINT', 'API Endpoint') { |v| @options[:api_endpoint] = v }
        opts.on('-s', '--stackid=STACKID', 'OpsWorks Stack ID') { |v| @options[:stackid] = v }
        opts.on('-k', '--kms=KMS_KEY_ID', 'KMS key id to use for encrypting private key, which will be stored within the ejson') { |v| @options[:kms] = v }
        opts.on('-s', '--infra_secrets=INFRA_SECRETS', 'Infra Secrets Name') { |v| @options[:infra_secrets] = v }
      end,

    }

    global.order!

    @command = ARGV.shift
    if @command.nil? then
      STDERR.puts "ERROR: No command provided, please see --help"
      exit 1
    end

    if subcommands.key?(@command)
      subcommands[@command].order!
    else
      STDERR.puts "ERROR: Unknown command - #{@command}"
      exit 1
    end
  end

  # Bit of heuristic to find sensitive keys. This is to ease automatic
  # transition from OpsWorks stack settings json (because we need to keep
  # sync'ing)
  def self.is_secret(key)
    return (key.include?("key") || key.include?("secret") ||
            key.include?("password") || key.include?("pwd") ||
            key.include?("token") || key.include?("ssh_id") ||
            key.include?("auth_header") || key.include?("app_id") ||
            key.include?("account_sid") || key.include?("client_id") ||
            key.include?("site_id") || key.include?("widget_id") ||
            key.include?("license") ||
            key.eql?("_public_key") || key.eql?("_private_key_enc") ||
            key.eql?("cert_id") || key.eql?("dev_id") ||
            key.eql?("ru_name") || key.eql?("google_business_calendar") ||
            key.eql?("kissmetrics") || key.include?("google_oauth2_client_id_ios") ||
            key.eql?("hosted_zone") || key.eql?("service") ||
            key.eql?("default-user") || key.eql?("free-user") ||
            key.eql?("parent") || key.eql?("user1") || key.eql?("user2") ||
            key.eql?("onedrive_client_id") || key.eql?("product_id") ||
            key.eql?("template_hash") || key.eql?("iv") ||
            key.eql?("marketo_api_subdomain"))
  end

  def self.is_infra_secret(key)
    return (key.include?("access_key_id") || key.include?("secret_access_key"))
  end

  def self.set_stack_meta
    begin
      stack_meta = JSON.parse(`opsworks-agent-cli get_json`)
      @options[:stackid] = stack_meta["opsworks"]["stack"]["id"] unless @options[:stackid]
      @options[:stackname] = stack_meta["opsworks"]["stack"]["name"] unless @options[:stackname]
      @options[:layer] = stack_meta["opsworks"]["instance"]["layers"].sort.first unless @options[:layer]
    rescue Exception => e
      @options[:stackname] = nil
      @options[:layer] = nil
      @options[:stackid] = nil
      STDERR.puts "Unable to get opsworks meta: #{e.inspect} \nSet stackname: #{@options[:stackname]} and layer: #{@options[:layer]} and id: #{@options[:stackid]}"
    end
  end

  def self.decrypt()
    require 'ejson_wrapper'

    if !@options.key?(:file) then
      STDERR.puts "File to decrypt not provided. Please see --help"
      exit 1
    end

    if !@options[:layer] then
      STDERR.puts "ERROR: Required option --layer is missing"
      exit 1
    end

    if !@options[:stackname] then
      STDERR.puts "ERROR: Required option --stackname is missing"
      exit 1
    end

    STDERR.puts "Using settings file: #{@options[:file]}"

    if !File.file?(@options[:file]) then
      STDERR.puts "ERROR: File #{@options[:file]} doesn't exit, please check"
      exit 1
    end

    if @options.key?(:kms) then
      STDERR.puts "Decrypting ejson with KMS encrypted private key"
      if !@options.key?(:region) then
        STDERR.puts "--region option not provided, please see --help"
        exit 1
      end
    end

    s = EJSONWrapper.decrypt(@options[:file], region: @options[:region],
                             use_kms: @options.key?(:kms), key_dir: @options[:private_key_dir])

    if @options.key?(:override_ejson)
      if !File.file?(@options[:override_ejson])
        STDERR.puts "Override EJSON file not present. Exiting."
        exit 1
      else
        o = EJSONWrapper.decrypt(@options[:override_ejson], region: @options[:region],
                             use_kms: @options.key?(:kms), key_dir: @options[:private_key_dir])
        s = s.deep_merge(o)
        if ENV['SQUAD'] == '1' && o[:settings] && o[:settings][:ymls] && o[:settings][:ymls][:database]
          ejson_prepare(o, false)
          o = o.deep_symbolize_keys
          @database_config = o[:settings][:ymls][:database]
        end
      end
    end

    ejson_prepare(s, false)

    s = s.deep_symbolize_keys()

    if @options.key?(:layer) then
      if !s.key?(:settings) then
        STDERR.puts "ERROR: in #{@options[:file]} file, \"settings\" key is missing"
        exit 1
      end

      if !s.key?(:layer_settings) then
        STDERR.puts "ERROR: in #{@options[:file]} file, \"layer_settings\" key is missing"
        exit 1
      end

      if !s[:layer_settings].key?(@options[:layer].to_sym) then
        STDERR.puts "WARNING: in #{@options[:file]} file, in \"layer_settings\", \"#{@options[:layer].to_sym}\" is missing"
        s[:layer_settings][@options[:layer].to_sym] ||= {}
      end

      # settings-*.json contains "settings" and "layer_settings"
      # The layer_settings values will override values in "settings"
      @settings = s[:settings].deep_merge(s[:layer_settings][@options[:layer].to_sym])
    else
      @settings = s
    end

    # Add/Fix up keys
    if ENV["HELPKIT_TEST_SETUP_ENABLE"] == "1"
      # We need to use the full name for redis namespace, we want the shell
      # to be self-container w.r.t jobs created/consumed
      @settings[:unique_keys][:sidekiq][:namespace] = "sidekiq-#{@options[:stackname]}"
      @settings[:unique_keys][:redis][:namespace] = "resque-#{@options[:stackname]}"
      STDERR.puts "Using sidekiq namespace: #{@settings[:unique_keys][:sidekiq][:namespace]}"
      STDERR.puts "Using resque namespace: #{@settings[:unique_keys][:redis][:namespace]}"
    else
      if @options[:stackname].split("-").size != 4
        STDERR.puts "Stack Name is not in proper convention! It might cause sidekiq namespace mismatches"
      end

      color = @options[:stackname].split("-")[-1]
      if !(color.eql?("blue") or color.eql?("green"))
        STDERR.puts "Incorrect color name: #{color} (computed from stackname: #{@options[:stackname]})"
        exit 1
      end
      shell = @options[:stackname].split("-")[-2]
      @settings[:unique_keys][:sidekiq][:namespace] = "sidekiq-#{shell}-#{color}"
      @settings[:unique_keys][:redis][:namespace] = "resque-#{shell}-#{color}"
    end

    if @options.key?(:infra_secrets)
      require 'aws-sdk-secretsmanager'
      client = Aws::SecretsManager::Client.new(region: @options[:region])
      begin
        infra_secrets = JSON.parse(client.get_secret_value({secret_id: @options[:infra_secrets]}).secret_string)
        infra_secrets = infra_secrets.deep_symbolize_keys()
        @settings.deep_merge!(infra_secrets)
      rescue Aws::SecretsManager::Errors::ResourceNotFoundException => e
        STDERR.puts "Infra Secret #{@options[:infra_secrets]} not found in SecretsManager."
        exit 1
      end
    end

    if @options.key?(:override_json)
      if !File.file?(@options[:override_json])
        STDERR.puts "Override JSON file not present. Exiting."
        exit 1
      else
        begin
          override_settings = JSON.parse(File.open(@options[:override_json]).read)
          override_settings = override_settings.deep_symbolize_keys()
          @settings.deep_merge!(override_settings)
        rescue JSON::ParserError => e
          STDERR.puts "Invalid JSON value. Not exiting. proceeding without override"
        end
      end
    end

    return
  end

  def self.encrypt()
    require "open3"
    if !File.file?(@options[:file]) then
      STDERR.puts "ERROR: File #{@options[:file]} doesn't exit, please check"
      exit 1
    end

    STDERR.puts "Encrypting settings file: #{@options[:file]}"
    cmd = ['ejson', 'encrypt', @options[:file]]
    stdout, status = Open3.capture2e(*cmd)
    if !status.success? then
      STDERR.puts "Encrypting failed: #{status} #{stdout}"
    end
  end

  def self.generate()
    require 'ejson_wrapper'

    if !@options.key?(:file) then
      STDERR.puts "Output file path not provided. Please see --help"
      exit 1
    end

    if @options.key?(:kms) then
      STDERR.puts "Generating ejson with KMS encrypted key"
      if !@options.key?(:region) then
        STDERR.puts "--region option not provided, please see --help"
        exit 1
      end

      EJSONWrapper.generate(region: @options[:region], kms_key_id: @options[:kms], file: @options[:file])
      STDERR.puts "Done"
    else
      if !@options.key?(:private_key_dir) then
        STDERR.puts "Neither --kms nor --private_key_dir provided, please see --help"
        exit 1
      end

      cmd = ['ejson', 'keygen', '--write']
      env={'EJSON_KEYDIR' => @options[:private_key_dir]}

      stdout, status = Open3.capture2(env, *cmd)
      if !status.success? then
        STDERR.puts "Keygen failed: #{status} #{stdout}"
      end

      ejson_file = JSON.pretty_generate(
        {
          '_public_key' => stdout.split("\n")[0],
          'settings' => { 'ymls' => {} },
          'layer_settings' => {}
        }
      )

      File.write(@options[:file], ejson_file)
      puts "Generated EJSON file #{@options[:file]}"
    end
  end

  def self.generate_falcon_assets()
    require 'erubis'
    decrypt()
    node = Node.new(@options, @settings)
    opsworks = OpsWorks.new(node, @options)
    color_code = opsworks.get_color()
    config_dir = "/data/shared"
    File.open("#{config_dir}/deploy.js", "wb") do |f|
      @settings[:falcon_ui][:s3][:bucket] = @settings[:falcon_ui][color_code.to_sym][:bucket]
      @settings[:falcon_ui][:fingerprint_prepend] = @settings[:falcon_ui][color_code.to_sym][:fingerprint_prepend]
      @settings[:ember_frontend_s3] = @settings[:falcon_ui][color_code.to_sym][:ember_frontend_s3]
      @falcon_ui = @settings[:falcon_ui]
      @opsworks_access_keys = @settings[:opsworks_access_keys]
      template = File.open("/data/falcon-config/deploy.js.erb").read
      content = Erubis::Eruby.new(template).result(binding)
      f.write(content)
      f.close
    end

    File.open("#{config_dir}/stack-config.js", "wb") do |f|
      @settings[:falcon_ui][:s3][:bucket] = @settings[:falcon_ui][color_code.to_sym][:bucket]
      @settings[:falcon_ui][:fingerprint_prepend] = @settings[:falcon_ui][color_code.to_sym][:fingerprint_prepend]
      @settings[:ember_frontend_s3] = @settings[:falcon_ui][color_code.to_sym][:ember_frontend_s3]
      node = @settings
      use_tag = node[:falcon_ui][:sentry] && node[:falcon_ui][:sentry][:usetag] ? "#{node[:falcon_ui][:sentry][:usetag]}"  : ""
      if use_tag.eql? "true"
        release_id = @options[:revision]
      else
        release_hash = `cd /data/helpkit-ember && git log -1 --format="%H"`.gsub(/\n/,"")
        release_id = 'FD_' + Time.now.strftime('%y.%m.%d') + "-#{release_hash}"
      end
      node[:release_id] = release_id
      template = File.open("/data/falcon-config/stack-config.js.erb").read
      content = Erubis::Eruby.new(template).result(binding)
      f.write(content)
      f.close
    end
  end

  def self.generate_config()
    require 'erubis'

    if !@options[:region] then
      STDERR.puts "ERROR: Required option --region is missing"
      exit 1
    end

    if !@options[:environment] then
      STDERR.puts "ERROR: Required option --environment is missing"
      exit 1
    else
      if !(@options[:environment] == "staging" or @options[:environment] == "production") then
        STDERR.puts "ERROR: Option --environment contains invalid value: " + @options[:environment]
        STDERR.puts "ERROR: It must be either staging or production"
        exit 1
      end
    end

    if !@options[:layer] then
      STDERR.puts "ERROR: Required option --layer is missing"
      exit 1
    end

    if !@options[:hostname] then
      STDERR.puts "ERROR: Required option --hostname is missing"
      exit 1
    end

    if !@options[:outdir] then
      STDERR.puts "ERROR: Required option --outdir is missing"
      exit 1
    end

    if !@options.key?(:file) then
      STDERR.puts "ERROR: Required option --file is missing"
      exit 1
    end

    if !@options.key?(:indir) then
      STDERR.puts "ERROR: Required option --indir is missing"
      exit 1
    end

    if !@options.key?(:infra_secrets) then
      STDERR.puts "INFRA SECRETS file name not provided. Please see --help"
      exit 1
    end

    if !@options[:private_ip] then
      STDERR.puts "ERROR: Required option --private_ip is missing"
      exit 1
    end

    decrypt()

    # We will mock the opsworks node object. We want to ease the transition
    # period, so we will keep the ERB files same for time being.
    node = Node.new(@options, @settings)
    opsworks = OpsWorks.new(node, @options)

    STDERR.puts "CPU Count: #{node[:cpu][:total]}"

    @is_app_layer = opsworks.app_layer?()
    @is_fc_api_layer = opsworks.fc_api_layer?()
    @is_fc_app_layer = opsworks.fc_app_layer?()
    @is_pipeline_layer = opsworks.pipeline_layer?()
    @is_support_layer = opsworks.support_layer?()
    @is_fc_api_public_layer = opsworks.fc_api_public_layer?()
    @is_fc_api_channel_layer = opsworks.fc_api_channel_layer?()
    @is_freshid_layer = opsworks.freshid_layer?()
    @is_resque_layer = opsworks.resque_layer?()
    @is_sidekiq_layer = opsworks.sidekiq_layer?()
    @is_sidekiq_archive_layer = opsworks.sidekiq_archive_layer?()
    @is_maintenance_redis_enabled = opsworks.maintenance_redis_enabled?()
    @is_shoryuken_layer = opsworks.shoryuken_layer?()
    @is_fc_shoryuken_layer = opsworks.fc_shoryuken_layer?()
    @is_reports_layer = opsworks.reports_layer?()
    @is_migration_layer = opsworks.migration_layer?()
    @color_code = opsworks.get_color()

    @is_hk_layer = opsworks.hk_layer?()
    @is_fc_layer = opsworks.fc_layer?()
    @is_app_layer = opsworks.app_layer?()
    @is_bg_layer = opsworks.bg_layer?()


    @pool_size = opsworks.get_pool_size()

    @envoy_egress_allowed = envoy_egress_allowed?
    @tracing_allowed = open_telemetry_allowed?

    if ENV["HELPKIT_TEST_SETUP_ENABLE"] == "1"
      rename_sqs_queues_for_test_setup(node)
    end

    d = File.join("#{@options[:indir]}", "*.erb")
    STDERR.puts "Using input directory: #{d}"

    files = Dir.glob(d)
    if files.empty? then
      STDERR.puts "Couldn't find *.erb files in #{d}"
      exit 1
    end

    sandbox_dir = File.join(@options[:outdir], "sandbox")
    unless File.directory?(sandbox_dir)
      FileUtils.mkdir_p(sandbox_dir)
    end

    # sql.yaml.erb expects sqs_queues keys to be string, not symbols
    node[:ymls][:sqs_queues].deep_stringify_keys!


    STDERR.puts("Merging credentials from secrets manager")
    require 'aws-sdk-secretsmanager'
    client = Aws::SecretsManager::Client.new(region: @options[:region])
    begin
      secret_name =  node[:ymls][:database][:secret_key]
      secrets_manager_data = JSON.parse(client.get_secret_value({secret_id: secret_name}).secret_string)
      STDOUT.puts "Secret #{secret_name} is found so reusing it."
      secrets_manager_data = secrets_manager_data.deep_symbolize_keys()
      node.deep_merge!(secrets_manager_data)
    rescue Aws::SecretsManager::Errors::ResourceNotFoundException => e
      STDOUT.puts "Secret #{secret_name} not found so creating it."
    end

    node[:ymls][:sidekiq].deep_merge!(sidekiq_redis_from_env)

    node[:ymls][:database] = @database_config if @database_config

    files.each {|filename|
      STDERR.puts "Processing #{filename}"
      if node[:yml_search].include?(File.basename(filename)) then
        out = @options[:outdir] + "/search/" + File.basename(filename, ".*")
      else
        out = @options[:outdir] + "/" + File.basename(filename, ".*")
      end

      dirname = File.dirname(out)
      unless File.directory?(dirname)
        FileUtils.mkdir_p(dirname)
      end

      skip_file_list = [
        "newrelic.yml.erb",
        "sidekiq.monitrc.erb",
        "shoryuken.monitrc.erb",
        "resque.monitrc.erb",
        "resque-scheduler.monitrc.erb",
        "deploy.js.erb",
        "stack-config.js.erb"
      ]

      if skip_file_list.any?{ |skip_file| filename.include?(skip_file) }
        next
      elsif filename.include?("sidekiq_client.yml.erb")
        if @is_sidekiq_layer then
          SidekiqConfig::setup(node, opsworks, @options, filename, File.join(@options[:indir], "sidekiq.monitrc.erb"))
        end
      elsif filename.include?("resque.conf.erb")
        if @is_resque_layer then
          ResqueConfig::setup(node, opsworks, @options, @options[:indir])
        end
      elsif filename.include?("sandbox.yml.erb")
        @public_key = File.join("/data/helpkit/shared/config/sandbox", node[:ymls][:sandbox][:public_key])
        @private_key = File.join("/data/helpkit/shared/config/sandbox", node[:ymls][:sandbox][:private_key])
        File.open(out, 'w') do |f|
          f.write(Erubis::Eruby.new(File.read(filename)).result(binding))
        end
        @public_key = nil
        @private_key = nil
      elsif filename.include?("git_config.erb")
        @host = node[:sandbox_host]
        @file = File.join(sandbox_dir, node[:sandbox_files][1])
        out = "/home/deploy/.ssh/config"
        File.open(out, 'w') do |f|
          f.write(Erubis::Eruby.new(File.read(filename)).result(binding))
        end
        @host = nil
        @file = nil
        FileUtils.chown("deploy", "nginx", out)
        File.chmod(0600, out)
      elsif filename.include?("shoryuken.yml.erb")
        ShoryukenConfig::setup(node, opsworks, @options, filename, File.join(@options[:indir], "shoryuken.monitrc.erb"))
      else
        File.open(out, 'w') do |f|
          f.write(Erubis::Eruby.new(File.read(filename)).result(binding))
        end
      end
    }

    generate_newrelic_config(node, opsworks)

    # TODO: Move these into ejson file (or to SecretsManager)
    #
    # Download sandbox configuration. S3 download!
    download_sandbox_certs(node, sandbox_dir)

    # Download integration certifications
    download_integration_certs(node)
  end

  def self.sidekiq_redis_from_env
    redis_address = sidekiq_redis_address
    config = {}

    if redis_address
      config[:host] = redis_address[0]
      config[:port] = redis_address[1]
      config[:password] = ENV['SIDEKIQ_REDIS_PASSWORD'] if ENV['SIDEKIQ_REDIS_PASSWORD'].present?
    end
    config
  end

  def self.sidekiq_redis_address
    return nil unless ENV['SIDEKIQ_REDIS_ADDRESS'].present?

    address_regex = /[A-Za-z0-9.-]*:[0-9]+/
    unless address_regex.match(ENV['SIDEKIQ_REDIS_ADDRESS'])
      STDERR.puts 'SIDEKIQ_REDIS_ADDRESS is not in expected format'
      exit 0
    end
    ENV['SIDEKIQ_REDIS_ADDRESS'].split(':')
  end

  def self.is_ejson_boxed_message(msg)
    # Check here for format https://github.com/Shopify/ejson/blob/master/crypto/boxed_message.go
    msg.scan(/\AEJ\[(\d):([A-Za-z0-9+=\/]{44}):([A-Za-z0-9+=\/]{32}):(.+)\]\z/).length > 0
  end

  def self.validate()
    if !File.file?(@options[:file]) then
      STDERR.puts "ERROR: File #{@options[:file]} doesn't exit, please check"
      exit 1
    end

    STDERR.puts "Validating file: #{@options[:file]}"

    ej = JSON.parse(File.read(@options[:file]))

    is_valid = true

    ej.deep_locate -> (key, value, object) do
      if value.is_a?(::Hash) || key.nil?
        return false
      end

      if key.start_with?("_") then
        return false
      end

      if value.is_a?(::Array)
        value.each { |v|
          if v.is_a?(::String)
            if !is_ejson_boxed_message(v)
              puts "Error: Key \"#{key}\" and Value \"#{value}\" not encrypted"
              is_valid = false
            end
          end
        }
      else
        if value.is_a?(::String)
          if !is_ejson_boxed_message(value)
            puts "Error: Key \"#{key}\" and Value \"#{value}\" not encrypted"
            is_valid = false
          end
        end
      end

      false
    end

    if !is_valid
      STDERR.puts "ERROR: Invalid ejson file"
    end

    exit is_valid
  end

  def self.download_sandbox_certs(node, sandbox_dir)
    require 'aws-sdk-s3'
    s3 = Aws::S3::Client.new(:region => node[:opsworks_access_keys][:region])
    node[:sandbox_files].each do |sandbox_file|
      bucket = node[:ymls][:sandbox][:bucket]
      path = node[:ymls][:sandbox][:path]
      STDERR.puts("Downloading file from bucket: #{bucket} and key \"#{path}\" and file is #{sandbox_file}")
      #resp = s3.buckets[bucket].objects[path]

      outfile = File.join(sandbox_dir, sandbox_file)
      File.open(outfile, "wb") do |f|
        s3.get_object({:bucket => "#{node[:ymls][:sandbox][:bucket]}",
                       :key => "#{node[:ymls][:sandbox][:path]}/#{sandbox_file}"},
                      target: f)
        FileUtils.chown("deploy", "nginx", outfile)
        if outfile =~ /pub$/ then
          File.chmod(0644, outfile)
        else
          File.chmod(0600, outfile)
        end
      end
    end
  end

  def self.download_integration_certs(node)
    cert_dir = File.join(@options[:outdir], "cert", "integrations", "xero")
    FileUtils.mkdir_p(cert_dir)
    FileUtils.chown("deploy", "nginx", cert_dir)
    File.chmod(0755, cert_dir)

    require 'aws-sdk-s3'
    # passing region explicitly. As Xero & Common certs do not have any delta across S3 buckets, using from a single bucket.
    s3 = Aws::S3::Client.new(:region => "us-east-1")
    node[:xero][:cert_names].each do |cert_name|
      STDERR.puts("Downloading file from bucket: #{node[:xero][:bucket]} and key: #{node[:xero][:path]} and file is #{cert_name}")
      outfile = File.join(cert_dir, cert_name)
      File.open(outfile, "wb") do |f|
        s3.get_object({:bucket => "#{node[:xero][:bucket]}",
                       :key => "#{node[:xero][:path]}/#{cert_name}"},
                      target: f)
        FileUtils.chown("deploy", "nginx", outfile)
        File.chmod(0400, outfile)
      end
    end

    cert_dir = File.join(@options[:outdir], "cert")
    node[:common_certs][:cert_names].each do |cert_name|
      STDERR.puts("Downloading file from bucket: #{node[:common_certs][:bucket]} and key: #{node[:common_certs][:path]} and file is #{cert_name}")
      outfile = File.join(cert_dir, cert_name)
      File.open(outfile, "wb") do |f|
        s3.get_object({:bucket => node[:common_certs][:bucket],
                       :key => "#{node[:common_certs][:path]}/#{cert_name}"},
                      target: f)
        FileUtils.chown("deploy", "nginx", outfile)
        File.chmod(0400, outfile)
      end
    end
  end

  def self.envoy_egress_allowed?
    STDERR.puts("Checking envoy egress is allowed and the passed value is ENV['ENVOY_EGRESS'] => #{ENV['ENVOY_EGRESS']}")
    ENV['ENVOY_EGRESS'] == "true"
  end

  def self.open_telemetry_allowed?
    STDERR.puts("Checking opentelemetry ruby is allowed and the passed value is ENV['OPENTELEMETRY_RUBY_ENABLE'] => #{ENV['OPENTELEMETRY_RUBY_ENABLE']}")
    ENV['OPENTELEMETRY_RUBY_ENABLE'] == 'true'
  end

  def self.generate_newrelic_config(node, opsworks)
    STDERR.puts("Generating newrelic configuration")
    # puts JSON.pretty_generate(node[:opsworks])
    # exit 0
    non_monitoring_instance = ["riak-resque-","akismet-resque-","import-resque-","scheduler"]
    can_monitor_instance = !non_monitoring_instance.any? { |name_prefix| node[:opsworks][:instance][:hostname].include?(name_prefix) }
    agent_enabled = node[:newrelic][:enabled] && can_monitor_instance && (ENV['SQUAD'] != '1' || ENV['PRERUN'] == '1') ? true : false
    ssl_enabled = (!node[:newrelic][:ssl].nil?) ? node[:newreilc][:ssl] : false
    STDERR.puts("Newrelic enabled in current instance: (#{node[:opsworks][:instance][:hostname]}) : : : #{agent_enabled}")
    suffix = {
      "fc-app" => "-falcon",
      "fc-app-api-public" => "-api",
      "fc-app-merge" => "-merge",
      "fc-app-misc" => "-misc",
      "fc-app-archive" => "-archive",
      "fc-app-reports" => "-reports",
      "fc-app-api-channel" => "-channel",
      "fc-app-mobihelp" => "-mobihelp",
      "fc-app-freshid" => "-freshid",
      "fc-app-freshops" => "-freshops",
      "fc-app-email" => "-email",
      "fc-app-search" => "-search",
      "fc-app-support" => "-support",
      "fc-app-support-theme" => "-support-theme",
      "fc-app-solution" => "-solution",
      "fc-app-freshfone" => "-freshfone",
      "fc-app-api-contacts" => "-api-contacts",
      "fc-app-suggest" => "-suggest",
      "fc-app-http-request" => "-integrations",
      "fc-app-attachment" => "-attachment",
      "fc-bg-sidekiq" => "-sidekiq",
      "fc-bg-resque" => "-raketasks",
      "fc-bg-utility" => "-raketasks",
      "fc-bg-shoryuken" => "-shoryuken",
      "fc-app-pipeline" => "-pipeline",
      "hk-app-pipeline" => "-pipeline"
    }

    shell = opsworks.get_shell()
    color_code = opsworks.get_color()

    suffix_name = suffix[node[:opsworks][:instance][:layers].first]

    # This specific change is for making email background jobs report to email layer
    if node[:opsworks][:instance][:hostname].include?("shoryuken-sidekiq-email-cluster") || node[:opsworks][:instance][:hostname].include?("shoryuken-email-cluster")
      suffix_name = "-email"
    end

    if @settings[:req_shadowing] && @settings[:req_shadowing][:enabled]
      suffix_name += "-shadow"
    end

    global_collector = node[:ymls][:pods][:current_pod] + "-" + "#{node[:ymls][:newrelic][:product_name]} ;"

    nr_in = File.join("#{@options[:indir]}", "newrelic.yml.erb")
    STDERR.puts "Using newlic template: #{nr_in}"

    nr_out = File.join("#{@options[:outdir]}", "newrelic.yml")
    File.open(nr_out, 'w') do |f|
      @rails_env = node[:opsworks][:environment]
      @squad = (ENV['SQUAD'] == '1' && ENV['PRERUN'] != '1')
      @app_name = "helpkit"
      @suffix = suffix_name.to_s
      @shell = shell
      @current_pod = node[:ymls][:pods][:current_pod]
      @gb_collector = global_collector.to_s
      @license_key = node[:ymls][:newrelic][:license_key]
      @agent_enabled = "#{agent_enabled}"
      @color_code = color_code
      @ssl_enabled = ssl_enabled
      @distributed_tracing_enabled = node[:ymls][:newrelic][:distributed_tracing_enabled]

      f.write(Erubis::Eruby.new(File.read(nr_in)).result(binding))
    end
  end

  def self.rename_sqs_queues_for_test_setup(node)
    STDERR.puts "SQS: Renaming SQS queues for test setup"

    queues_keys_to_rename = [
      :active_customer_email_queue,
      :bot_feedback_queue,
      :channel_framework_services,
      :custom_mailbox_realtime_queue,
      :custom_mailbox_status,
      :default_email_queue,
      :email_dead_letter_queue,
      :email_events_queue,
      :facebook_realtime_queue,
      :fb_message_realtime_queue,
      :fd_email_failure_reference,
      :fd_scheduler_reminder_todo_queue,
      :forums_moderation_queue,
      :free_customer_email_queue,
      :helpdesk_reports_export_queue,
      :reports_service_export_queue,
      :scheduled_export_payload_enricher_queue,
      :scheduled_ticket_export_complete,
      :search_etl_queue,
      :sidekiq_fallback_queue,
      :social_fb_messenger,
      :sqs_es_index_queue,
      :trial_customer_email_queue,
      :fd_scheduler_export_cleanup_queue,
      :fd_scheduler_downgrade_policy_reminder_queue,
      :analytics_etl_queue,
      :email_rate_limiting_queue,
      :freddy_consumed_session_reminder_queue,
      :switch_to_annual_notification_queue
    ]

    sqs_shoryken = {
      "active_customer_email_queue": "active_email",
      "default_email_queue": "default_email",
      "email_dead_letter_queue": "failed_emails",
      "facebook_realtime_queue": "social_fb_feed",
      "fd_email_failure_reference": "email_failure_reference",
      "fd_scheduler_reminder_todo_queue": "reminder_todo",
      "free_customer_email_queue": "free_email",
      "scheduled_export_payload_enricher_queue": "scheduled_export_payload",
      "scheduled_ticket_export_complete": "scheduled_ticket_export",
      "search_etl_queue": "search_etlqueue",
      "trial_customer_email_queue": "trial_email",
      'fd_scheduler_downgrade_policy_reminder_queue': 'downgrade_policy_reminder',
      'suspended_account_cleanup_queue': 'suspended_account_cleanup',
      'switch_to_annual_notification_queue': 'switch_to_annual_notification'
    }

    queue_prefix = ENV["HELPKIT_TEST_SETUP_SQS_QUEUE_PREFIX"]
    if !queue_prefix or queue_prefix == ""
      STDERR.puts "Error: HELPKIT_TEST_SETUP_SQS_QUEUE_PREFIX env variable is not set"
      exit 1
    end

    node[:ymls][:sqs_queues].keys.each do |k|
      next unless queues_keys_to_rename.include?(k)
      sufix = sqs_shoryken.keys.include?(k) ? sqs_shoryken[k].to_s : k.to_s
      new_name = prefixing(sufix)
      STDERR.puts("\tFor key '#{k}', renaming '#{node[:ymls][:sqs_queues][k]}' to '#{new_name}'")
      node[:ymls][:sqs_queues][k] = new_name
    end

    STDERR.puts "\n\tQueues after rename: #{node[:ymls][:sqs_queues].inspect}"
  end

  def self.prefixing(sufix)
    "#{ENV["HELPKIT_TEST_SETUP_SQS_QUEUE_PREFIX"]}_#{sufix}"
  end


  def self.prepare_json_to_ejson()
    if !@options.key?(:file) then
      STDERR.puts "Input json file path not provided. Please see --help"
      exit 1
    end

    s = JSON.parse(File.read(@options[:file]))
    ejson_prepare(s, true)
    File.write(@options[:file], JSON.pretty_generate(s))
    #puts JSON.pretty_generate(s)
  end

  def self.generate_ejson_from_opsworks()
    require 'ejson_wrapper'

    set_stack_meta

    if !@options.key?(:file) then
      STDERR.puts "file not provided. Please see --help"
      exit 1
    end

    if !@options.key?(:region) then
      STDERR.puts "region not provided. Please see --help"
      exit 1
    end

    if !@options.key?(:stackid) then
      STDERR.puts "Stack ID not provided. Please see --help"
      exit 1
    end

    if !@options.key?(:kms) then
      STDERR.puts "KMS key id not provided. Please see --help"
      exit 1
    end

    if !@options.key?(:infra_secrets) then
      STDERR.puts "INFRA SECRETS file name not provided. Please see --help"
      exit 1
    end

    settings = nil
    if File.file?(@options[:file]) then
      ej = JSON.parse(File.read(@options[:file]))
      if ej.key?("_public_key") && ej.key?("_private_key_enc") then
        settings = { "_public_key" => ej["_public_key"],
                     "_private_key_enc" => ej["_private_key_enc"] }
      end
    end

    if settings.nil? then
      EJSONWrapper.generate(region: @options[:region], kms_key_id: @options[:kms], file: @options[:file])
      settings = JSON.parse(File.read(@options[:file]))
    end

    require 'aws-sdk-opsworks'

    if @options.key?(:api_endpoint)
      region = @options[:api_endpoint]
    else
      region = @options[:region]
    end

    client = Aws::OpsWorks::Client.new({:region => region})

    # Get stack settings
    resp = client.describe_stacks({:stack_ids => [@options[:stackid]]})
    if resp.stacks.length < 1 then
      STDERR.puts("ERROR: Cannot find the stack #{@options[:stackid]}")
      exit 1
    end

    stack_settings = JSON.parse(resp.stacks[0].custom_json)

    # Get layer settings
    resp = client.describe_layers({:stack_id => @options[:stackid]})
    if resp.layers.length < 1 then
      STDERR.puts("ERROR: Cannot find layers in stack #{@options[:stackid]}: #{resp}")
      exit 1
    end

    layer_settings = {}
    resp.layers.each { |layer|
      if layer.custom_json.nil? then
        layer_settings[layer.name] = {}
      else
        layer_settings[layer.name] = JSON.parse(layer.custom_json)
      end
    }

    # Put them all together
    settings["settings"] = {
        "ymls" => stack_settings["ymls"],
        "unique_keys" => stack_settings["unique_keys"],
        "falcon_ui" => stack_settings["falcon_ui"],
        "aws_config" => stack_settings["aws_config"],
        "opsworks_access_keys" => stack_settings["opsworks_access_keys"],
        "config_gen" => stack_settings["config_gen"],
        "opsworks" => stack_settings["opsworks"],
        "xero" => stack_settings["xero"],
        "common_certs" => stack_settings["common_certs"],
        "newrelic" => stack_settings["newrelic"],
        "docker" => stack_settings["docker"],
        "stack_config" => stack_settings["stack_config"],
        "shoryuken" => stack_settings["shoryuken"]
    }
    settings["layer_settings"] = layer_settings

    # delete the keys in settings variable
    infra_settings, settings["settings"] = split_infra_secrets(settings["settings"])
    # store sensitive values in infra secrets

    if @options.key?(:infra_secrets)
      require 'aws-sdk-secretsmanager'
      client = Aws::SecretsManager::Client.new(region: @options[:region])
      begin
        secrets_manager_data = JSON.parse(client.get_secret_value({secret_id: @options[:infra_secrets]}).secret_string)
        STDOUT.puts "Secret #{@options[:infra_secrets]} is found so reusing it."
        secrets_manager_data = secrets_manager_data.deep_symbolize_keys()
        infra_settings.deep_merge!(secrets_manager_data)
      rescue Aws::SecretsManager::Errors::ResourceNotFoundException => e
        STDOUT.puts "Secret #{@options[:infra_secrets]} not found so creating it."
        response = client.create_secret({
          name: @options[:infra_secrets],
          secret_string: infra_settings.to_json
        })
      end
    end

    File.write(@options[:file], JSON.pretty_generate(settings))

    prepare_json_to_ejson()
    encrypt()
  end

  def self.split_infra_secrets(stack_settings, prefix=[], infra_settings={})
    if !(stack_settings.is_a?(Hash) || stack_settings.is_a?(Array))
      return
    end

    case stack_settings.class.to_s
    when "Hash"
      stack_settings.each do |key, value|
        prefix.push(key)
        split_infra_secrets(value, prefix, infra_settings)
        if is_infra_secret(key.to_s)
          infra_settings.deep_merge!(recursive_hash_store(prefix.dup, stack_settings.delete(key).dup))
        end
        prefix.pop
      end
    when "Array"
      stack_settings.each do |value|
        split_infra_secrets(value, prefix, infra_settings)
      end
    end
    return infra_settings, stack_settings
  end

  def self.recursive_hash_store(key_array, value)
    element = key_array.slice!(0)
    if element
      return {element => recursive_hash_store(key_array, value)}
    else
      return value
    end
  end

  # Prefix or remove "_"  in non-secret keys
  def self.ejson_prepare(myObj, add_prefix)
    if !(myObj.is_a?(Hash) || myObj.is_a?(Array)) then
      return
    end

    case myObj.class.to_s
    when "Hash"
      myObj.dup.each {|key, value|
        ejson_prepare(value, add_prefix)
        if value.is_a?(Hash) then
          next
        end

        if !is_secret(key.to_s) then
          if add_prefix then
            myObj["_" + key] = myObj.delete(key)
          else
            if key.to_s.start_with?("_")
              key_d = key.to_s.dup()
              key_d.slice!("_")
              myObj[key_d] = myObj.delete(key)
            end
          end
        end
      }
    when "Array"
      myObj.each {|value|
        ejson_prepare(value, add_prefix)
      }
    end
  end

  def self.process()
    case @command
    when "generate_config"
      generate_config
    when "generate_falcon_assets"
      generate_falcon_assets
    when "decrypt"
      decrypt
      puts(JSON.pretty_generate(@settings))
    when "encrypt"
      encrypt
    when "generate"
      generate
    when "validate"
      validate
    when "prepare_ejson"
      prepare_json_to_ejson
    when "generate_ejson_from_opsworks"
      generate_ejson_from_opsworks
    else
      STDERR.puts "ERROR: Unknown command: @command"
    end
  end
end

# https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/hash/deep_merge.rb
class Hash
  # Returns a new hash with +self+ and +other_hash+ merged recursively.
  #
  #   h1 = { a: true, b: { c: [1, 2, 3] } }
  #   h2 = { a: false, b: { x: [3, 4, 5] } }
  #
  #   h1.deep_merge(h2) # => { a: false, b: { c: [1, 2, 3], x: [3, 4, 5] } }
  #
  # Like with Hash#merge in the standard library, a block can be provided
  # to merge values:
  #
  #   h1 = { a: 100, b: 200, c: { c1: 100 } }
  #   h2 = { b: 250, c: { c1: 200 } }
  #   h1.deep_merge(h2) { |key, this_val, other_val| this_val + other_val }
  #   # => { a: 100, b: 450, c: { c1: 300 } }
  def deep_merge(other_hash, &block)
    dup.deep_merge!(other_hash, &block)
  end

  # Same as +deep_merge+, but modifies +self+.
  def deep_merge!(other_hash, &block)
    merge!(other_hash) do |key, this_val, other_val|
      if this_val.is_a?(Hash) && other_val.is_a?(Hash)
        this_val.deep_merge(other_val, &block)
      elsif block_given?
        block.call(key, this_val, other_val)
      else
        other_val
      end
    end
  end

  # https://github.com/intridea/hashie/blob/master/lib/hashie/extensions/deep_locate.rb
  def deep_locate(comparator)
    _deep_locate(comparator, self)
  end

  def _deep_locate(comparator, object, result = [])
    if object.is_a?(::Enumerable)
      result.push object if object.any? { |value| _match_comparator?(value, comparator, object) }
      (object.respond_to?(:values) ? object.values : object.entries).each do |value|
        _deep_locate(comparator, value, result)
      end
    end
  end

  def _match_comparator?(value, comparator, object)
    if object.is_a?(::Hash)
      key, value = value
    else
      key = nil
    end

    comparator.call(key, value, object)
  end
end

class Object
  # https://gist.github.com/Integralist/9503099
  def deep_symbolize_keys
    return self.reduce({}) do |memo, (k, v)|
      memo.tap { |m| m[k.to_sym] = v.deep_symbolize_keys }
    end if self.is_a? Hash

    return self.reduce([]) do |memo, v|
      memo << v.deep_symbolize_keys; memo
    end if self.is_a? Array

    self
  end

  def present?
    !blank?
  end

  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  #File activesupport/lib/active_support/core_ext/hash/keys.rb, line 114
  def deep_stringify_keys!
    deep_transform_keys!{ |key| key.to_s }
  end

  # File activesupport/lib/active_support/core_ext/hash/keys.rb, line 95
  def deep_transform_keys!(&block)
    _deep_transform_keys_in_object!(self, &block)
  end

  # File activesupport/lib/active_support/core_ext/hash/keys.rb, line 152
  def _deep_transform_keys_in_object!(object, &block)
    case object
    when Hash
      object.keys.each do |key|
        value = object.delete(key)
        object[yield(key)] = _deep_transform_keys_in_object!(value, &block)
      end
      object
    when Array
      object.map! {|e| _deep_transform_keys_in_object!(e, &block)}
    else
      object
    end
  end
end

HelpkitDynamicConfig.init
HelpkitDynamicConfig.process

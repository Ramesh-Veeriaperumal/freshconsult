# In lib/helpdesk/initializers/ruby193_monkey_patches.rb, we are monkey
# patching Marshal.load() method to enforce utf8 encoding for string objects
# (even when they are already utf8). That was needed during ruby 1.8 to 1.9
# transition and is likely not needed any more. Leaving that imposes huge
# perf penalty for all memcache calls (2x slowdown), so we undo the monkey
# patch here.
if ENV['DISABLE_MEMCACHE_UTF8_ENFORCEMENT'] == 'true'
  module MarshalOrg
    include Marshal
    class << self
      def load(obj, other_proc=nil)
        Marshal.load_without_utf8_enforcement(obj, other_proc)
      end

      def dump(obj)
        Marshal.dump(obj)
      end
    end
  end
  memcacheserializer = MarshalOrg
else
  memcacheserializer = Marshal
end

# The below config is used for caching the app data. (Groups, Agent, TicketFields)
config = YAML::load_file(File.join(Rails.root, 'config', 'dalli.yml'))[Rails.env].symbolize_keys!
servers = config.delete(:servers)
options = { :namespace => "helpkit_#{$$}", :compress => config[:compress], :socket_max_failures => config[:socket_max_failures], :socket_timeout => config[:socket_timeout], :serializer => memcacheserializer }
$memcache = Dalli::Client.new(servers, options)

# The below config is used for controller caching(page, action, fragment) offered by rails
custom_config = YAML::load_file(File.join(Rails.root, 'config', 'custom_dalli.yml'))[Rails.env].symbolize_keys!
custom_servers = custom_config.delete(:servers)
ActionController::Base.cache_store = :dalli_store, custom_servers, custom_config
custom_options = { :namespace => "helpkit_custom_#{$$}", :compress => custom_config[:compression], :socket_max_failures => custom_config[:socket_max_failures], :socket_timeout => custom_config[:socket_timeout] }
$custom_memcache = Dalli::Client.new(custom_servers, custom_options)
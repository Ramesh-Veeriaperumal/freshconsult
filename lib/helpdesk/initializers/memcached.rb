config = YAML::load_file(File.join(Rails.root, 'config', 'dalli.yml'))[Rails.env].symbolize_keys!
servers = config.delete(:servers)
options = { :namespace => config[:namespace], :compress => true}
$memcache = Dalli::Client.new(servers, options)
ActionController::Base.cache_store = :dalli_store, servers, config
# TODO-RAILS3 Need to cross check dalli store as any diff with mem_cache_store, If so, think of caching the new keys inadvance.

begin
  config = YAML::load_file(File.join(Rails.root, 'config', 'dalli.yml'))[Rails.env].symbolize_keys!
  servers = config.delete(:servers)
  options = { :namespace => config[:namespace], :compress => true}
  $dalli = Dalli::Client.new(servers, options)
rescue => e
  puts "Rails 3 migration yml is not configured properly"
end




# Bellow peace of code can be removed once everything got migrated.
begin
  config = YAML::load_file(File.join(Rails.root, 'config', 'memcached.yml'))[Rails.env].symbolize_keys!
  servers = config.delete(:servers)
  options = { :namespace => config[:namespace], :compress => true}
  $dalli = Dalli::Client.new(servers, options)
rescue => e
  puts "Rails 3 migration yml is not configured properly"
end

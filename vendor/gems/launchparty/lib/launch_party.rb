require 'redis'
class LaunchParty
  
  STORE_KEYS = {
    :account_wise => "%{namespace}:%{id}:features",
    :feature_wise => "%{namespace}:%{feature}:accounts",
    :everyone => "%{namespace}/everyone"
  }
  
  DEFAULTS = {
    :namespace => 'launch_party'
  }
  
  @@default_store = nil
  @@options = DEFAULTS
  
  def self.configure(opts)
    @@default_store = opts[:redis] if opts[:redis]
    @@options = opts.reject {|key,val| key == :redis }
    true
  end
  
  def self.default_store
    @@default_store || raise("Redis Connection not set")
  end
  
  def self.default_options
    DEFAULTS.merge(@@options)
  end
  
  def initialize(store=nil, options={})
    @store = store || self.class.default_store
    @options = self.class.default_options.merge(options)
  end
  
  def launch(feature, account)
    toggle_for_account(feature, account, true)
  end
  
  def launched_for_account(account)
    @store.smembers(account_wise_key(:id => idify(account))).map(&:to_sym)
  end
  
  def launched?(feature, account)
    return true if 
    @store.sismember(account_wise_key(:id => idify(account)), feature)
  end
  
  def toggle_for_account(feature, account, launch = true)
    method = launch ? :sadd : :srem
    @store.send(method, account_wise_key(:id => idify(account)), feature.to_s)
    @store.send(method, feature_wise_key(:feature => feature), idify(account))
  end
  
  def takeback(feature, account)
    toggle_for_account(feature, account, false)
  end
  
  def takeback_everything_for_account(account)
    account = idify(account)
    @store.smembers(account_wise_key(:id => account)).each do |feature|
      @store.srem(feature_wise_key(:feature => feature), account)
    end
    @store.del(account_wise_key(:id => account))
  end
  
  # Replace everyone by all
  def launch_for_everyone(feature)
    @store.sadd(everyone_key, feature)
  end
  
  def launched_for_everyone?(feature)
    @store.sismember(everyone_key, feature)
  end
  
  def launched_for_everyone
    @store.smembers(everyone_key).map(&:to_sym)
  end
  
  def takeback_for_everyone(feature)
    @store.smembers(feature_wise_key(:feature => feature)).each do |acc_id|
      @store.srem(account_wise_key(:id => acc_id), feature)
    end
    @store.del(feature_wise_key(:feature => feature))
    @store.srem(everyone_key, feature)
  end
  
  
  
  alias :clear_feature :takeback_for_everyone

  def idify(obj)
    return obj.id if obj.respond_to?(:id)
    obj.to_i
  end
  
  STORE_KEYS.each do |key, value|
    define_method "#{key}_key" do |options={}|
      value % ({
        :namespace => @options[:namespace]
      }).merge(options)
    end
  end
  
end

require 'launch_party/extenders'
Class.instance_eval do
  include LaunchParty::Extenders
end

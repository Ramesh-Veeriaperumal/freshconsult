class Fdadmin::AccountToolsController < Fdadmin::DevopsMainController

  include Redis::OthersRedis
  include Redis::RedisKeys
  include Redis::ReportsRedis
  include Cache::Memcache::GlobalBlacklistIp

  before_filter :validate_method_names, :only => [:operations_on_shard]
  before_filter :validate_shard, only: [:add_shard_to_redis]

  BLOCKTYPE = {
    :ip => 1,
    :domain => 2
  }

	def index
		respond_to do |format|
      format.json do
        render :json => blacklisted_ips.ip_list
        # render :json => $rate_limit.perform_redis_op("smembers", Redis::RedisKeys::HAPROXY_IP_BLACKLIST_KEY)
      end
    end
	end

  def blacklisted_domains
    respond_to do |format|
      format.json do
        render :json => $rate_limit.perform_redis_op("smembers", Redis::RedisKeys::HAPROXY_DOMAIN_BLACKLIST_KEY)
      end
    end
  end

  def shards
    result = Sharding.all_shards
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def fetch_latest_shard
    result = ShardMapping.latest_shard
    respond_to do |format|
      format.json do
        render json: result.to_json
      end
    end
  end

  def operations_on_shard 
    if FreshopsToolsWorkerMethods::SHARD_OPS.has_value?(params["method_name"])
      params["shards_name"].each do |shard_name|
        FreshopsToolsWorker.perform_async({:shards_name => shard_name , :method_name => params["method_name"]})
      end
    else
      FreshopsToolsWorker.perform_async(params)
    end
    respond_to do |format|
      format.json do
        render :json => {:status => "success"}
      end
    end
  end

  def update_global_blacklist_ips
    params[:ip_list].strip!
    result = {}
    if valid_ip?(params[:ip_list])
      message_hash = { :value => params[:ip_list], :action => "add", :blocktype => BLOCKTYPE[:ip]}
      begin
        $rate_limit.perform_redis_op("sadd", Redis::RedisKeys::HAPROXY_IP_BLACKLIST_KEY, params[:ip_list])
        $rate_limit.perform_redis_op("publish", Redis::RedisKeys::HAPROXY_IP_BLACKLIST_CHANNEL, message_hash.to_json)
      rescue Exception => e
        Rails.logger.error("Exception Adding IP to the HAProxy blacklist ::::: #{e}")
        NewRelic::Agent.notice_error(e)
      end
      item = GlobalBlacklistedIp.first
      blacklisted_ip_list = item.ip_list ? item.ip_list : []
      blacklisted_ip_list << params["ip_list"] if !blacklisted_ip_list.include?(params["ip_list"])
      item.ip_list = blacklisted_ip_list
      if item.save
        result[:status] = "success"
      else
        result[:status] = "error"
      end
    else
      result[:status] = "error"
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def remove_blacklisted_ip
    message_hash = { :value => params[:whitelist_ip], :action => "remove", :blocktype => BLOCKTYPE[:ip]}
    result = {}
    begin
      $rate_limit.perform_redis_op("srem", Redis::RedisKeys::HAPROXY_IP_BLACKLIST_KEY, params[:whitelist_ip])
      $rate_limit.perform_redis_op("publish", Redis::RedisKeys::HAPROXY_IP_BLACKLIST_CHANNEL, message_hash.to_json)
    rescue Exception => e
      Rails.logger.error("Exception Removing IP from the HAProxy blacklist ::::: #{e}")
      NewRelic::Agent.notice_error(e)
    end
    item = GlobalBlacklistedIp.first
    blacklisted_ip_list = item.ip_list ? JSON.parse(item.ip_list.to_json) : []
    blacklisted_ip_list.delete(params[:whitelist_ip]) if blacklisted_ip_list.include?(params[:whitelist_ip])
    item.ip_list = blacklisted_ip_list
    if item.save
      result[:status] = "success"
    else
      result[:status] = "error"
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def add_blacklisted_domain
    params[:domain].strip!
    result = {}
    message_hash = { :value => params[:domain], :action => "add", :blocktype => BLOCKTYPE[:domain]}
    begin
      redis_result = $rate_limit.perform_redis_op("sadd", Redis::RedisKeys::HAPROXY_DOMAIN_BLACKLIST_KEY, params[:domain])
      $rate_limit.perform_redis_op("publish", Redis::RedisKeys::HAPROXY_IP_BLACKLIST_CHANNEL, message_hash.to_json)
      result[:status] = redis_result.nil? ? "error" : "success"
    rescue Exception => e
      Rails.logger.error("Exception Adding Domain to the HAProxy blacklist ::::: #{e}")
      NewRelic::Agent.notice_error(e)
      result[:status] = "error"
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def remove_blacklisted_domain
    params[:domain].strip!
    result = {}
    message_hash = { :value => params[:domain], :action => "remove", :blocktype => BLOCKTYPE[:domain]}
    begin
      redis_result = $rate_limit.perform_redis_op("srem", Redis::RedisKeys::HAPROXY_DOMAIN_BLACKLIST_KEY, params[:domain])
      $rate_limit.perform_redis_op("publish", Redis::RedisKeys::HAPROXY_IP_BLACKLIST_CHANNEL, message_hash.to_json)
      result[:status] = redis_result.nil? ? "error" : "success"
    rescue Exception => e
      Rails.logger.error("Exception Removing IP from the HAProxy blacklist ::::: #{e}")
      NewRelic::Agent.notice_error(e)
      result[:status] = "error"
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def redis_signup_shards
    shards = get_all_members_in_a_redis_set(LATEST_SHARDS)
    respond_to do |format|
      format.json do
        render json: { latest_shards: shards }
      end
    end
  end

  def add_shard_to_redis
    shard = params[:shard]
    status = add_member_to_redis_set(LATEST_SHARDS, shard)
    respond_to do |format|
      format.json do
        render json: { status: status }
      end
    end
  end

  def remove_shard_from_redis
    shard = params[:shard]
    status = remove_member_from_redis_set(LATEST_SHARDS, shard)
    respond_to do |format|
      format.json do
        render json: { status: status }
      end
    end
  end

  private 
    def validate_shard
      unless Sharding.all_shards.include? params[:shard].to_s
        head 400
        render json: { message: 'invalid shard'} && return
      end
    end

    def validate_method_names
      if ["add_to_shard","remove_from_shard","dynamic_rubyscript_evaluation"].include?(params[:method_name])
        return true 
      else
        respond_to do |format|
          format.json do
            render :json => {:status => "No method exists with this name"}
          end
        end
      end
    end

    def valid_ip? ip
      IPAddress.valid_ipv4?(ip) || IPAddress.valid_ipv6?(ip)
    end
end

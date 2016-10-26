class Fdadmin::AccountToolsController < Fdadmin::DevopsMainController

	include Redis::RedisKeys
	include Redis::ReportsRedis
  include Cache::Memcache::GlobalBlacklistIp

  before_filter :validate_method_names, :only => [:operations_on_shard]

	def index
		black_ip = []
		blacklisted_ips.ip_list.each do |ip|
			black_ip << ip
		end
		respond_to do |format|
      format.json do
        render :json => black_ip
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
		result = {}
		item = GlobalBlacklistedIp.first
    blacklisted_ip_list = item.ip_list ? item.ip_list : []
    blacklisted_ip_list << params["ip_list"] if !blacklisted_ip_list.include?(params["ip_list"])
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

  def remove_blacklisted_ip
    result = {}
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

   private 

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
end

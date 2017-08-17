module Cache::Memcache::Reports::ReportsCache

  include MemcacheKeys

  GENERAL_TIMEOUT_MINS = 60;
  DEFAULT_TIMEOUT_SECONDS = 30 * 60 ; 

  def get_key_for_insights(request_params)
    "REPORTS:INSIGHTS:#{Account.current.id}:#{Digest::MD5.hexdigest(stringify(request_params))}"
  end

  def stringify(obj)
  	if obj.class == Hash
  		obj.sort.to_s
  	else 
  		obj.to_s
  	end
  end 

  def get_cache_interval_from_synctime( last_dump_time )
     last_dump_time ||= 0
  	 timeout = Time.at(last_dump_time)+GENERAL_TIMEOUT_MINS.minutes - Time.now 
  	 timeout > 0 ? timeout.to_i : DEFAULT_TIMEOUT_SECONDS
  end
  # def stringify(obj)
  #   if obj.class == Hash
  #     arr = []
  #     obj.each do |key, value|
  #       arr << "#{stringify key}=>#{stringify value}"
  #     end
  #     obj = arr
  #   elsif obj.class == Array
  #     str = ''
  #     obj.map! do |value|
  #       stringify value
  #     end.sort!.each do |value|
  #       str << value
  #     end
  #   elsif obj.class != String
  #     obj = obj.to_s << obj.class.to_s
  #   end

  #   obj
  # end
  
end

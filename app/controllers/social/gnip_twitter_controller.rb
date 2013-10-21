class Social::GnipTwitterController < ApplicationController
  
  include Redis::GnipRedisMethods
  include Social::Gnip::Constants
  skip_before_filter :check_privilege  

  filter_parameter_logging :hash
  
  def reconnect 
    if verify_params? && update_reconnect_time_in_redis(params[:reconnect_time]) 
      render :json => {
      	:success => true,
         :text => "Reconnect time successfully updated" 
      }          	
    else
      NewRelic::Agent.notice_error("Reconnect time updation failed", 
                          					:custom_params => params.inspect)
      render :json => {
      	:success => false,
         :text => "Reconnect time updatiom failed :: custom_params => #{params.inspect}"
      }
    end
  end
  
  
  private
  
    def verify_params?
      return false unless (params[:reconnect_time] && params[:hash])
      epoch = Time.now.to_i / TIME[:reconnect_timeout]
      data = "#{params[:reconnect_time]}#{epoch}"
      digest  = OpenSSL::Digest::Digest.new('sha512')
      hash = OpenSSL::HMAC.hexdigest(digest, GnipConfig::GNIP_SECRET_KEY, data)
      valid_request = (hash == params[:hash])
    end
end

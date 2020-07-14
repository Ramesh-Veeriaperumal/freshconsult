class Social::GnipTwitterController < ApplicationController

  include Redis::GnipRedisMethods
  include Social::Twitter::Constants
  include Social::Util

  skip_before_filter :check_privilege, :verify_authenticity_token

  # TODO-RAILS3 password moved to application.rb but need to check hash
  #filter_parameter_logging :hash

  def reconnect
    if verify_params? && update_reconnect_time_in_redis(params[:reconnect_time])
      render :json => {
      	:success => true,
         :text => "Reconnect time successfully updated"
      }
    else
      notify_social_mailer(nil, params, 'Reconnect time updation failed')
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
      digest  = OpenSSL::Digest.new('sha512')
      hash = OpenSSL::HMAC.hexdigest(digest, GnipConfig::GNIP_SECRET_KEY, data)
      valid_request = (hash == params[:hash])
    end
end

class Fdadmin::DevopsMainController < Fdadmin::MetalApiController
  
  before_filter :set_time_zone
  before_filter :verify_signature
  before_filter :check_freshops_subdomain

  include Fdadmin::APICalls
  private
    def verify_signature
      payload = ""
      request.query_parameters.each do |key , value |
        payload << "#{key}#{value.to_s}" unless key.to_s == "digest"
      end
      payload = payload.chars.sort.join
      sha_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('MD5'), determine_api_key, payload)
      if sha_signature != params[:digest]
        Rails.logger.debug(": : : SIGNATURE VERIFICATION FAILED : : :")
        head 401
        render :json => {:message => "Authorization failed"} and return
      end
      Rails.logger.debug(": : : -> SHA SIGNATURE VERIFIED <- : : :")
    end

    def set_time_zone
      Time.zone = 'Pacific Time (US & Canada)'
    end

    def check_freshops_subdomain
      raise ActionController::RoutingError, "Not Found" unless freshops_subdomain?
    end

    def freshops_subdomain?
      FreshopsSubdomains.include?(request.subdomains.first)
    end

    def select_by_parameter
      input_params = params[:account_id] if params[:account_id]
      input_params = params[:domain_name] if params[:domain_name]
      input_params
    end

    def select_master_shard
      Rails.logger.debug "Selecting via MASTER SHARD"
      Sharding.admin_select_shard_of(select_by_parameter) do
        yield
      end
    end

    def select_slave_shard
      Rails.logger.debug "Selecting via SLAVE SHARD"
      Sharding.admin_select_shard_of(select_by_parameter) do
        Sharding.run_on_slave do
          yield
        end
      end
    end

    def run_on_slave
      Sharding.run_on_slave do
        yield
      end
    end

end

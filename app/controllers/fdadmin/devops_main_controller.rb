class Fdadmin::DevopsMainController < ApplicationController

  skip_before_filter :check_privilege
  skip_before_filter :set_time_zone
  skip_before_filter :set_current_account
  skip_before_filter :set_locale
  skip_before_filter :check_account_state
  skip_before_filter :ensure_proper_protocol
  skip_before_filter :check_day_pass_usage
  skip_around_filter :select_shard
  prepend_before_filter :set_time_zone
  before_filter :verify_signature
  before_filter :check_freshops_subdomain

  private
    def verify_signature
      payload = ""
      request.query_parameters.each do |key , value |
        payload << "#{key}#{value.to_s}" unless key.to_s == "digest"
      end
      sha_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('MD5'), determine_api_key, payload)
      if sha_signature != params[:digest]
         Rails.logger.debug(": : : SIGNATURE VERIFICATION FAILED : : :")
        render :nothing => true, :status => 401 and return
      end
      Rails.logger.debug(": : : -> SHA SIGNATURE VERIFIED <- : : :")
    end

    def set_time_zone
      Time.zone = 'Pacific Time (US & Canada)'
    end

    def determine_api_key
      app_name = params[:app_name] || "freshopsadmin"
      return ServiceApiKey.find_by_service_name(app_name).api_key 
    end

    def check_freshops_subdomain
      raise ActionController::RoutingError, "Not Found" unless freshops_subdomain?
    end

    def freshops_subdomain?
      request.subdomains.first == AppConfig['freshops_subdomain']
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

end

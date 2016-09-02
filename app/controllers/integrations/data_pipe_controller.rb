class Integrations::DataPipeController <  ApplicationController
  include Marketplace::ApiMethods
  include Marketplace::ApiUtil

  before_filter :app_installed?, :only => [:router]

  def router
    begin 
      account_id = Account.current.id
      shard = ShardMapping.lookup_with_account_id(account_id)
      additional_params = { extensionId: request.headers["HTTP_MKP_EXTNID"], versionId: request.headers["HTTP_MKP_VERSIONID"],
        accountId: account_id, accountPod: shard.pod_info, 
        installedExtnId: @installed_extn_id, mkpRoute: request.headers["HTTP_MKP_ROUTE"]
      }
      request_body = params[:data_pipe].merge(additional_params)
      resp = make_request(request_body) 
      render :json => resp.body, :status => resp.status
    rescue => e
      exception_logger("Data Pipe params: #{params}, mkpRoute: #{request.headers["HTTP_MKP_ROUTE"]}, 
                        Exception: #{e.message}\n#{e.backtrace}");
      render :nothing => true, :status => 500
    end
  end

  private 
    def app_installed?
      extns = installed_extensions({ type: Marketplace::Constants::EXTENSION_TYPE[:plug]})
      render_error and return if error_status?(extns)
      extns.body.each do |extn|
        if(extn["extension_id"] == request.headers["HTTP_MKP_EXTNID"].to_i && extn["version_id"] == request.headers["HTTP_MKP_VERSIONID"].to_i)
          @installed_extn_id = extn["installed_extension_id"]
        end
      end
      if(@installed_extn_id.blank?)
        return render_error
      end
    end

    def render_error
      render :json => "Invalid Request", :status => 400
    end

    def make_request(body)
      date_header = Time.now
      router_url = "#{MarketplaceConfig::DATA_PIPE_URL}/dp-router"
      FreshRequest::Client.new(
        api_endpoint: router_url,
        payload: body,
        circuit_breaker: MarketplaceConfig::DPROUTER_CB,
        headers: {
          'Content-Type' => 'application/json',
          'MKP-APIKEY' => MarketplaceConfig::DATA_PIPE_KEY,
          'Authorization' => generate_md5_digest("#{router_url}_#{date_header}", MarketplaceConfig::DATA_PIPE_AUTH_KEY),
          "Date" => date_header 
        },
        conn_timeout: MarketplaceConfig::DATA_PIPE_TIMEOUT[:conn],
        read_timeout: MarketplaceConfig::DATA_PIPE_TIMEOUT[:read]
      ).post
    end
end
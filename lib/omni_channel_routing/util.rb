module OmniChannelRouting
  module Util
    include ::OmniChannelRouting::Constants

    def request_service(client_service, http_method, path, payload = {}, use_mars = false)
      request_params = {}
      request_params[:method] = http_method.to_sym
      request_params[:payload] = payload if http_method.to_sym == :put
      request_params[:headers] = ocr_headers(client_service)
      request_params[:timeout] = 10
      request_params[:open_timeout] = 10
      request_params[:url] = use_mars ? mars_url(path) : ocr_url(path)
      RestClient::Request.execute(request_params)
    end

    def ocr_url(path)
      "#{OCR_BASE_URL}#{path}"
    end

    def mars_url(path)
      "#{MARS_BASE_URL}#{path}"
    end

    def service_paths(use_mars = false)
      use_mars ? MARS_PATHS : OCR_PATHS
    end

    def ocr_headers(client_service)
      {
        'Authorization' => "Token #{ocr_jwt_token(client_service)}",
        'Content-Type'  => 'application/json',
        'X-Request-ID'  => "#{Thread.current[:message_uuid].try(:first)}"
      }
    end

    def ocr_jwt_token(client_service)
      JWT.encode(
        ocr_jwt_payload(client_service),
        OCR_CLIENT_SECRET_KEYS[client_service.to_sym],
        OCR_JWT_SIGNING_ALG,
        OCR_JWT_HEADER
      )
    end

    def ocr_jwt_payload(client_service)
      acc_id = client_service.to_sym == :admin ? Account.current.ocr_account_id : Account.current.id
      {
        account_id: acc_id.to_s,
        service: OCR_CLIENT_SERVICES[client_service.to_sym],
        actor: User.current.try(:id).to_s
      }
    end

    def log_request_header
      Rails.logger.debug "X-OCR-UUID :: #{request.headers['X-OCR-UUID']}"
    end

    def touchstone_request?
      @touchstone_request ||= request.headers['X-Touchstone'].presence == TOUCHSTONE_SECRET
    end

  end
end

module OmniChannelRouting
  module Util
    include ::OmniChannelRouting::Constants

    def headers
      {
        'Authorization' => "Token #{jwt_token}",
        'Content-Type'  => 'application/json',
        'X-Request-ID'  => "#{Thread.current[:message_uuid].try(:first)}"
      }
    end
    
    def jwt_token
      JWT.encode payload, OCR_CONFIG[:jwt_secret], 'HS256', { 'alg' => 'HS256', 'typ' =>'JWT'}
    end

    def payload
      {
        account_id: Account.current.id.to_s,
        service: FRESHDESK_SERVICE
      }
    end

    def log_request_header
      Rails.logger.debug "X-OCR-UUID :: #{request.headers['X-OCR-UUID']}"
    end

  end
end

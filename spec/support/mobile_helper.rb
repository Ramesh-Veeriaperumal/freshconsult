module MobileHelper
    def json_response
     @json ||= JSON.parse(response.body)
    end

    def api_login
     @request.host = @account.full_domain
     @request.user_agent = "Freshdesk_Native_Android"
     @request.env['HTTP_AUTHORIZATION'] =  ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token,"X")
     @request.env["HTTP_ACCEPT"] = "application/json"
    end
end
module MobileHelper
    def json_response
      @json ||= JSON.parse(response.body)
    end
end
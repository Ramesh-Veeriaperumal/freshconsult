module Facebook
  module Exception
    module Constants
     
      AUTH_ERROR               = 190
      AUTH_SUB_CODES           = [458, 459, 460, 463, 464, 467]
      HTTP_STATUS_CLIENT_ERROR = [400, 499]
      HTTP_STATUS_SERVER_ERROR = [500, 599]
      APP_RATE_LIMIT           = 4
      USER_RATE_LIMIT          = 17
      PERMISSION_ERROR         = [200, 299]
      IGNORED_ERRORS           = [230, 275]
      ERROR_MESSAGES           = {:permission_error => "manage_pages",  :auth_error => "impersonate" }
      
    end
  end
end

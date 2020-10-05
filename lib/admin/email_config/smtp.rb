module Admin::EmailConfig::Smtp
  ERROR_MAP = {
    535 => 'authentication_error',
    401 => 'invalid_grant',
    601 => 'oauth_migration_required'
  }.freeze

  class ErrorMapper
    def initialize(error_type: nil)
      @error_type = error_type
    end

    def fetch_error_mapping
      ERROR_MAP[@error_type]
    end
  end
end

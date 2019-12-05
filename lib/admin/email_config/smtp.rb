module Admin::EmailConfig::Smtp
  ERROR_MAP = {
    530 => 'authentication_error',
    550 => 'relay_limit_exceeded',
    554 => 'transaction_failed'
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

module Admin::EmailConfig::Imap
  MANDATORY_FIELDS = [:pod_info, :account_id, :folder, :status, :mailbox_id, :user_name, :to_email]
  STATUS= %w(running suspended failed).freeze
  SUSPENDED = 1
  RUNNING = 0
  UNKNOWN_ERROR_TYPE = 2
  KNOWN_ERROR_MAP = {
      541 => 'invalid_login',
      542 => 'server_response_invalid',
      543 => 'email_bad_request',
      544 => 'mailbox_idle',
      545 => 'folder_unavailable',
      546 => 'unable_to_connect',
      547 => 'unable_fetch_status',
      548 => 'io_error',
      561 => 'ssl_errror',
      562 => 'tcp_connection',
      563 => 'tcp_refused',
      564 => 'server_no_resp',
      565 => 'bye_response',
      566 => 'tcp_socket',
      569 => 'io_error',
      601 => 'oauth_migration_required'
  }
  UNKNOWN_ERROR_MAP = {
      1 => 'mailbox_suspended',
      2 => 'unknown_error',
  }
  ERROR_MAP = KNOWN_ERROR_MAP.merge(UNKNOWN_ERROR_MAP)
  class ErrorMapper
    def initialize(error_type: nil)
      @error_type = error_type
    end
    def fetch_error_mapping
      return ERROR_MAP[@error_type]
    end
  end
end
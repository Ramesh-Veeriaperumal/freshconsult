module RTS
  module Constants
    SUCCESS_CODES = [200].freeze
    RTS_ACCOUNT_REGISTER = {
      end_point: "v1/account/register/#{RTSConfig['app_id']}",
      default_version: '1.0',
      default_description: 'Freshdesk RTS Account for %{account_name}',
      http_method: 'post'
    }.freeze
  end
end

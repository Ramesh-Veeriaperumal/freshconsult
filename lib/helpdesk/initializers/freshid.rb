infra_config = YAML.load_file(File.join(Rails.root, 'config', 'infra_layer.yml'))

if infra_config['FRESHID_LAYER']
  Helpkit::Application.configure do
    config.middleware.insert_before "Middleware::TrustedIp", "Middleware::FreshidCallbackApiAuthenticator"
  end
end

Freshid.user_class            = 'User'
Freshid.account_class         = 'Account'
Freshid.authorization_class   = 'Authorization'
Freshid.domain_mapping_class  = 'DomainMapping'
Freshid.events_to_track       = %w[PROFILE_UPDATED USER_ACTIVATED PASSWORD_UPDATED RESET_PASSWORD]
Freshid::CallbackMethods.safe_send(:prepend, Freshid::CallbackMethodsExtensions)
Freshid::ApiCalls.safe_send(:prepend, Freshid::ApiCallsExtensions)
Freshid::SnsErrorNotification.safe_send(:prepend, Freshid::SnsErrorNotificationExtensions)
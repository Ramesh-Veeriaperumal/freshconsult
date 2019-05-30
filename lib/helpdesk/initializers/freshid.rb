infra_config = YAML.load_file(File.join(Rails.root, 'config', 'infra_layer.yml'))

if infra_config['FRESHID_LAYER']
  Helpkit::Application.configure do
    config.middleware.insert_before "Middleware::TrustedIp", "Middleware::FreshidCallbackApiAuthenticator"
  end
end

Freshid.user_class                          = 'User'
Freshid.account_class                       = 'Account'
Freshid.authorization_class                 = 'Authorization'
Freshid.domain_mapping_class                = 'DomainMapping'
Freshid.organisation_class                  = 'Organisation'
Freshid.organisation_account_mapping_class  = 'OrganisationAccountMapping'
Freshid.events_to_track                     = %w[PROFILE_UPDATED USER_ACTIVATED PASSWORD_UPDATED RESET_PASSWORD]
Freshid.v2_events_to_track                  = %w[PASSWORD_RESET PASSWORD_CHANGED USER_UPDATED USER_ACTIVATED USER_ID_UPDATED
                                                ORGANISATION_UPDATED ORGANISATION_ACCOUNT_TRANSFERRED ACCOUNT_ORGANISATION_MAPPED]
Freshid.methods_configured_for_retry        = [:create_account, :delete_account, :update_account, :create_organisation_account_user]

Freshid::CallbackMethods.safe_send(:prepend, Freshid::CallbackMethodsExtensions)
Freshid::ApiCalls.safe_send(:prepend, Freshid::ApiCallsExtensions)
Freshid::SnsErrorNotification.safe_send(:prepend, Freshid::SnsErrorNotificationExtensions)
Freshid::V2::RequestHandler.safe_send(:prepend, Freshid::V2::RequestHandlerExtensions)
Freshid::V2::EventProcessor.safe_send(:prepend, Freshid::V2::EventProcessorExtensions)
Freshid::V2::Migration::Migrator.safe_send(:prepend, Freshid::V2::Migration::MigratorExtensions)
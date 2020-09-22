AppConfig = YAML.load_file(File.join(Rails.root, 'config', 'config.yml')).with_indifferent_access

INTEGRATION_URL = URI.parse(AppConfig['integrations_url'][Rails.env]).host

GLOBAL_INTEGRATION_URL = URI.parse(AppConfig['global_integration_url'][Rails.env]).host

FreshopsSubdomains =  AppConfig['freshops_subdomain'].map { |k,v| v }.flatten

NodeConfig = YAML.load_file(File.join(Rails.root, 'config', 'node_js.yml'))[Rails.env]

FreshcallerConfig = YAML.load_file(Rails.root.join('config', 'freshcaller.yml'))[Rails.env]

MailgunConfig = YAML.load_file(File.join(Rails.root, 'config', 'mailgun.yml'))[Rails.env]

AddonConfig = YAML.load_file(File.join(Rails.root, 'config', 'addons.yml'))

MailboxConfig = YAML.load_file(File.join(Rails.root, 'config', 'mailbox.yml'))[Rails.env]

BraintreeConfig = YAML.load_file(File.join(Rails.root, 'config', 'braintree.yml'))

CHANNEL_API_CONFIG  = YAML.load_file(File.join(Rails.root, 'config', 'channel_api_keys.yml'))[Rails.env].with_indifferent_access

CHANNEL_V2_API_CONFIG = YAML.load_file(File.join(Rails.root, 'config', 'channel_v2_api.yml'))[Rails.env]

FEATURE_DESC_MAP = YAML.load_file(Rails.root.join('config', 'feature_description_keys.yml'))[:feature_description_keys]

IMPORTANT_FEATURES = FEATURE_DESC_MAP.keys

OCR_CONFIG = YAML.load_file(File.join(Rails.root, 'config', 'ocr_config.yml'))[Rails.env].with_indifferent_access

RateLimitConfig = YAML.load_file(File.join(Rails.root, 'config', 'rate_limit.yml'))[Rails.env]

ChromeExtensionConfig = YAML.load_file(File.join(Rails.root, 'config', 'chrome_extension.yml'))[Rails.env]

MobileConfig = YAML.load_file(File.join(Rails.root, 'config', 'mobile_config.yml'))

AdminApiConfig = YAML.load_file(File.join(Rails.root,'config','fdadmin_api_config.yml'))

AutoIncrementId = YAML.load_file(File.join(Rails.root,'config','auto_increment_ids.yml'))[Rails.env][PodConfig["CURRENT_POD"]]

HashedData = YAML.load_file(File.join(Rails.root,'config','hashed_data.yml'))[Rails.env]

ThirdPartyAppConfig = YAML::load_file File.join(Rails.root, 'config', 'third_party_app_config.yml')

MlAppConfig = YAML.load_file(File.join(Rails.root,'config','ml_app.yml'))[Rails.env]

FdNodeConfig = YAML.load_file(File.join(Rails.root, 'config', 'fd_node_config.yml'))[Rails.env]

ArchiveNoteConfig = YAML::load_file(File.join(Rails.root, 'config', 'archive_note.yml'))[Rails.env]

IrisNotificationsConfig = YAML::load_file(File.join(Rails.root, 'config', 'iris_notifications.yml'))[Rails.env]

ArchiveSikdekiqConfig = YAML::load_file(File.join(Rails.root, 'config', 'archive_queue.yml'))[Rails.env]

FalconUiRouteMapping = YAML.load_file(File.join(Rails.root, 'config', 'route_mapping.yml'))

FalconUiReRouteMapping = YAML.load_file(File.join(Rails.root, 'config', 're_route_mapping.yml'))

PartnerSubdomains =  AppConfig['partner_subdomain'].map { |k,v| v }.flatten

KafkaCollectorConfig = YAML.load_file(File.join(Rails.root, 'config', 'kafka_collector.yml'))[Rails.env]

ChannelFrameworkConfig = YAML.load_file(File.join(Rails.root, 'config', 'channel_framework.yml'))[Rails.env]

SchedulerClientKeys = YAML.load_file(File.join(Rails.root, 'config', 'scheduler_client_keys.yml'))[Rails.env]

FreshmarketerConfig = YAML.load_file(Rails.root.join('config', 'freshmarketer.yml'))[Rails.env]

UnsupportedFeaturesList = YAML.load_file(Rails.root.join('config', 'features', 'unsupported_features.yml'))[Rails.env][PodConfig["CURRENT_POD"]]

ProactiveServiceConfig = YAML.load_file(Rails.root.join('config', 'proactive_service.yml'))[Rails.env]

AskNicelyConfig = YAML.load_file(Rails.root.join('config', 'ask_nicely.yml'))[Rails.env]

FrenoConfig = YAML.load_file(File.join(Rails.root, 'config', 'freno.yml'))[Rails.env]

FreddySkillsConfig = YAML.load_file(Rails.root.join('config', 'freddy_skills_config.yml'))[Rails.env].with_indifferent_access

FacebookGatewayConfig = YAML.load_file(Rails.root.join('config', 'facebook_gateway.yml'))[Rails.env]

CentralConfig = YAML.load(File.read("#{Rails.root}/config/central.yml"))[Rails.env]

ShiftConfig = YAML.load(File.read("#{Rails.root}/config/shift_config.yml"))[Rails.env]

RTSConfig = YAML.load_file(Rails.root.join('config', 'rts.yml'))[Rails.env]

GrowthHackConfig = YAML.load_file(File.join(Rails.root, 'config', 'growth_hack.yml')).with_indifferent_access

PlanFeaturesConfig = YAML.load_file(Rails.root.join('config', 'features', 'plan_features.yml')).with_indifferent_access

FreshIDConfig = YAML.load_file(Rails.root.join('config', 'freshid.yml'))[Rails.env]

SecureFieldConfig = YAML.load_file(Rails.root.join('config', 'jwe', 'secure_field.yml'))[Rails.env]

AuthzConfig = YAML.load_file(Rails.root.join('config', 'authz_config.yml'))[Rails.env].with_indifferent_access

AlohaConfig = YAML.load_file(Rails.root.join('config', 'aloha_config.yml'))[Rails.env].with_indifferent_access
FreshIDV2Config = YAML.load_file(Rails.root.join('config', 'freshid_v2.yml'))[Rails.env]

ProductPlansConfig = YAML.load_file(Rails.root.join('config', 'product_plan_mapping.yml')).with_indifferent_access

FreshcallerSubscriptionConfig = YAML.load_file(Rails.root.join('config', 'freshcaller_subscription_config.yml'))[Rails.env]

FreshchatSubscriptionConfig = YAML.load_file(Rails.root.join('config', 'freshchat_subscription_config.yml'))[Rails.env]

OmniFreshVisualsConfig = YAML.load_file(File.join(Rails.root, 'config/helpdesk_reports', 'omni_freshvisuals.yml'))[Rails.env].with_indifferent_access

OmniChannelDashboardConfig = YAML.load_file(Rails.root.join('config', 'omni_channel_dashboard.yml'))[Rails.env]

OmniChannelBundleConfig = YAML.load_file(Rails.root.join('config', 'omni_channel_bundle.yml'))[Rails.env]

TracingConfig = YAML.load_file(Rails.root.join('config', 'tracing.yml'))[Rails.env]

KbServiceConfig = YAML.load_file(Rails.root.join('config', 'kbservice.yml'))[Rails.env]

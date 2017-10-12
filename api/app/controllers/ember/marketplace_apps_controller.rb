module Ember
  class MarketplaceAppsController < ApiApplicationController
    include Marketplace::ApiMethods

    def index
      @installed_apps = []
      platform_version = Marketplace::Constants::PLATFORM_VERSIONS_BY_ID[:v2]
      key = MemcacheKeys::INSTALLED_APPS_V2 % { account_id: current_account.id }
      installed_params = { type: INSTALLED_APP_TYPES_V2 }
      begin
        installed_list ||= mkp_memcache_fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
          installed_extensions(installed_params)
        end
        installed_list.body.try(:each) do |installed_mkp_app|
          # Extension Details API for V2 apps
          extn_detail = extension_details_v2(installed_mkp_app['extension_id'], installed_mkp_app['version_id']).body
          if extn_detail['platform_details'][platform_version.to_s].include?(installed_mkp_app['version_id'])
            @installed_apps << { extension_details:  extn_detail }
                               .merge(installation_details: installed_mkp_app)
          end
        end
      rescue
        render_request_error :marketplace_service_unavailable, 503
      end
    end
  end
end

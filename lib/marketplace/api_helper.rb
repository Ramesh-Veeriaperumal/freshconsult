module Marketplace::ApiHelper
  include Marketplace::ApiMethods
  include Marketplace::ApiUtil

  def installed_mkp_apps(display_page)
    begin
      page = Marketplace::Constants::DISPLAY_PAGE[display_page]
      installed_mkp_apps_list(page)
      return error_message if error_status?(@installed_list)
      page == Marketplace::Constants::DISPLAY_PAGE[:integrations_list] ? installed_mkp_app_details : @installed_list.body
    rescue Exception => e
      Rails.logger.debug "Error while fetching installed plugs: \n#{e.message}\n#{e.backtrace.join("\n")}"
      NewRelic::Agent.notice_error(e)
      error_message
    end
  end

  private

    def installed_mkp_apps_list(page)
      key = MemcacheKeys::INSTALLED_FRESHPLUGS % {
            :page => page, :account_id => current_account.id, :platform_version => platform_version  }
      cache_invalidation = (page == Marketplace::Constants::DISPLAY_PAGE[:integrations_list]) ? 
                           MarketplaceConfig::INTEGRATIONS_CACHE_INVD_TIME : 
                           MarketplaceConfig::CACHE_INVALIDATION_TIME
      @installed_list ||= mkp_memcache_fetch(key, cache_invalidation) do
        installed_extensions(installed_params(page))
      end
      page == Marketplace::Constants::DISPLAY_PAGE[:integrations_list] ? @installed_list : installed_mkp_apps_urls(page)
    end

    def get_version_details(page)
      key = MemcacheKeys::INSTALLED_VERSIONS % {
            :page => page, :account_id => current_account.id, :platform_version => platform_version  }
      cache_invalidation = (page == Marketplace::Constants::DISPLAY_PAGE[:integrations_list]) ? 
                           MarketplaceConfig::INTEGRATIONS_CACHE_INVD_TIME : 
                           MarketplaceConfig::CACHE_INVALIDATION_TIME
      @v2_versions ||= mkp_memcache_fetch(key, cache_invalidation) do
        version_ids = @installed_list.body.map { |x| x['version_id']}
        v2_versions(version_ids)
      end
    end

    def set_app_urls
      @installed_list.body.try(:each) do |installed_mkp_app|
        version_details = @v2_versions.body['versions'].detect { |x| x['id'] == installed_mkp_app['version_id'] }
        unless version_details.nil?
          installed_mkp_app['app_url'] = version_details['app_url']
        end
      end
    end

    # Get details for installed versions to get the app URL. 
    def installed_mkp_apps_urls(page)
      # return error response or empty response.
      return @installed_list if @installed_list.body.blank?

      get_version_details(page)
      return error_message if error_status?(@v2_versions) && @v2_versions.body.nil?
      set_app_urls
    end

    def installed_mkp_app_details
      supported_mkp_apps, unsupported_mkp_apps, supported_custom_apps, unsupported_custom_apps = [], [], [], []
      @installed_list.body.try(:each) do |installed_mkp_app|
        extension_details = extension_details(installed_mkp_app['extension_id'], installed_mkp_app['extension_type']).body
        unless hidden_app?(extension_details['app_type'])
          installed_extension_details = { :extension_details => extension_details }
                                          .merge({:installation_details => installed_mkp_app})
          extension_type = custom_app?(extension_details['app_type'], installed_mkp_app['extension_type']) ? :custom : :mkp
          (supported_apps?(extension_details, installed_mkp_app['version_id']) ? 
            eval("supported_#{extension_type}_apps") : eval("unsupported_#{extension_type}_apps")) << installed_extension_details
        end
      end
      { :installed_mkp_apps => {:supported_apps => supported_mkp_apps, :unsupported_apps => unsupported_mkp_apps},
        :installed_custom_apps => {:supported_custom_apps => supported_custom_apps, :unsupported_custom_apps => unsupported_custom_apps} }
    end

    def supported_apps?(extension, version_id)
      # clear cache and fetch extension datails again if version_id of the app is not found in both the platforms
      extension = extension_details(extension['extension_id'], extension['type'], true).body unless extension['platform_details'].values.flatten.include?(version_id)
      ((extension['type'] == Marketplace::Constants::EXTENSION_TYPE[:plug] || custom_app?(extension['app_type'], extension['type'])) &&
       extension['platform_details'][platform_version].include?(version_id)) ||
       extension['platform_details'][platform_version] == true
    end

    def custom_app?(app_type, extension_type)
      # TODO: app_type should be removed after new ext type is added for custom app
      app_type == Marketplace::Constants::APP_TYPE[:custom] || 
      extension_type == Marketplace::Constants::EXTENSION_TYPE[:custom_app]
    end

    def hidden_app?(app_type)
      app_type == Marketplace::Constants::APP_TYPE[:hidden]
    end

    def installed_params(page)
      installed_params = { type: Marketplace::Constants::INSTALLED_LIST_EXTENSION_TYPES}
      return installed_params.merge!( {
          include: Marketplace::Constants::SECURE_IPARAMS
      }) if page == Marketplace::Constants::DISPLAY_PAGE[:integrations_list]

      installed_params.merge!(
      { 
        display_page: page,
        enabled: true 
      })
    end

    def plug_code_from_cache(version_id, app_url)
      key = MemcacheKeys::FRESHPLUG_CODE % { :version_id => version_id }
      MemcacheKeys.fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
        plug_code_from_s3(app_url)
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end

    def plug_code_from_s3(app_url)
      open(app_url).read
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end

    def freshplug_script(installed_plug)
      script = plug_code_from_cache(installed_plug[:version_id], installed_plug[:app_url])

      unless script.blank?
        liquid_objs = freshplug_liquids(installed_plug)
        Liquid::Template.parse(script.gsub("}}", " | encode_html}}")).render(liquid_objs, 
            :filters => [Integrations::FDTextFilter],
            :registers => { :plug_asset => installed_plug[:app_url]}).html_safe
      else
        error = []
        error << %(<div class='alert alert-error'>)
        error << t('marketplace.apps_unavailable')
        error << %( </div> )
        error.join(" ").html_safe
      end
    end

    def freshplug_liquids(installed_plug)
      config_liquids = installed_plug[:configs].blank? ? {} : {'iparam' => IparamDrop.new(installed_plug[:configs]) }
      default_liquids.merge(config_liquids).merge({'app_id' => "app_#{installed_plug[:extension_id]}_#{installed_plug[:version_id]}"})
    end

    def default_liquids
      defaults = { 'current_user' => current_user, 
                   'account_id' => current_account.id,
                   'portal_id' => current_portal.id }
      liquid_objs = @ticket ? { 'ticket' => @ticket, 'requester' => @ticket.requester} : 
                              { 'requester' => @user}
      defaults.merge(liquid_objs)
    end

    def error_message
      { :error => "Error while fetching installed plugs" }
    end
end
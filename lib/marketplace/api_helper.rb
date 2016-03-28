module Marketplace::ApiHelper
  include Marketplace::ApiMethods
  include Marketplace::ApiUtil

  def installed_plugs(display_page)
    begin
      installed_plugs = []
      installed_extn_list = installed_plugs_list(display_page)
      return error_message if error_status?(installed_extn_list)

      installed_extn_list.body.try(:each) do |installed_plug|
        installed_plugs << extension_details(installed_plug['version_id']).body.merge(installed_plug)
      end
      installed_plugs
    rescue Exception => e
      Rails.logger.debug "Error while fetching installed plugs: \n#{e.message}\n#{e.backtrace.join("\n")}"
      NewRelic::Agent.notice_error(e)
      error_message
    end
  end

  def installed_plugs_list(display_page)
    page = Marketplace::Constants::DISPLAY_PAGE[display_page]
    key = MemcacheKeys::INSTALLED_FRESHPLUGS % { 
          :page => page, :account_id => current_account.id }
    @installed_list ||= mkp_memcache_fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
      installed_extensions(installed_params(page))
    end
  end

  private

    def installed_params(page)
      installed_params = { type: Marketplace::Constants::DEFAULT_EXTENSION_TYPES}
      installed_params.merge!(
        { 
          display_page: page,
          enabled: true 
        }) unless page == Marketplace::Constants::DISPLAY_PAGE[:integrations_list]
      installed_params
    end

    def plug_code_from_cache(version_id)
      key = MemcacheKeys::FRESHPLUG_CODE % { :version_id => version_id }
      MemcacheKeys.fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
        plug_code_from_s3(version_id)
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end

    def plug_code_from_s3(version_id)
      s3_id = version_id.to_s.reverse
      open("https://#{MarketplaceConfig::CDN_STATIC_ASSETS}/#{s3_id}/#{Marketplace::Constants::PLG_FILENAME}").read
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end

    def freshplug_script(installed_plug)
      script = plug_code_from_cache(installed_plug[:version_id])

      liquid_objs = freshplug_liquids(installed_plug[:configs])
      Liquid::Template.parse(script).render(liquid_objs, 
          :filters => [Integrations::FDTextFilter],
          :registers => { :plug_asset => installed_plug[:version_id]}).html_safe
    end

    def freshplug_liquids(configs)
      config_liquids = configs.blank? ? {} : {'iparam' => IparamDrop.new(configs) }
      default_liquids.merge(config_liquids)
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
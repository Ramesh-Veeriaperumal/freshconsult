module Marketplace::ApiHelper
  include Marketplace::ApiMethods

  def installed_plugs(display_page)
    page = Marketplace::Constants::DISPLAY_PAGE[display_page]
    key = MemcacheKeys::INSTALLED_FRESHPLUGS % { 
          :page => page, :account_id => current_account.id }
    @installed_plugs ||= MemcacheKeys.fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
      installed_extensions(installed_params(page))
    end
  rescue Exception => e
    NewRelic::Agent.notice_error(e)
  end

  private

    def installed_params(page)
      installed_params = { type: Marketplace::Constants::EXTENSION_TYPE[:plug]}
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
      AwsWrapper::S3Object.read("#{s3_id}/#{s3_id}.html",
        MarketplaceConfig::S3_ASSETS)
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end

    def freshplug_script(installed_plug)
      script = installed_plug[:in_dev] ?
         plug_code_from_s3(installed_plug[:version_id]) :
         plug_code_from_cache(installed_plug[:version_id])

      liquid_objs = freshplug_liquids(installed_plug[:configs])
      Liquid::Template.parse(script).render(liquid_objs, 
          :filters => [Integrations::FDTextFilter],
          :registers => { :plug_asset => installed_plug[:version_id], 
                :in_development =>  installed_plug[:in_dev]}).html_safe
    end

    def freshplug_liquids(configs)
      config_liquids = configs.blank? ? {} : {'plug' => PlugDrop.new(JSON.parse(configs)) }
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
end
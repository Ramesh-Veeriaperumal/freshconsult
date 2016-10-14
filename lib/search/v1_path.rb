# Constraint class for routing to V2 paths
module Search
  module V1Path

    class WebPath

      V1_WEB_PATHS = [
                        '/search',
                        '/support/search',
                        '/contact_merge/search',
                        '/freshfone/autocomplete'
                      ]

      def matches?(request)
        # Web paths
        if ((V1_WEB_PATHS.find { |path| request.path.starts_with?(path) }.present?) && 
            !request.user_agent.to_s[/#{AppConfig['app_name']}_Native/].present?)
            account_id = ShardMapping.lookup_with_domain(request.host).try(:account_id).to_i
            LaunchParty.new.launched?(feature: :es_v2_reads, account: account_id) rescue false
        end
      end
    end
    
    class MobilePath
    
      V1_MOBILE_PATHS = [
                          '/helpdesk/autocomplete',
                          '/helpdesk/authorizations',
                          '/search/home',
                          '/search/tickets/filter',
                          '/mobile/tickets/get_suggested_solutions'
                        ]
    
      def matches?(request)
        # Web paths
        if ((V1_MOBILE_PATHS.find { |path| request.path.starts_with?(path) }.present?) && 
            request.user_agent.to_s[/#{AppConfig['app_name']}_Native/].present?)
            account_id = ShardMapping.lookup_with_domain(request.host).try(:account_id).to_i
            LaunchParty.new.launched?(feature: :es_v2_reads, account: account_id) rescue false
        end
      end
    end

  end
end
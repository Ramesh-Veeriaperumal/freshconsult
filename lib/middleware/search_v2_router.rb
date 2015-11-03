##################################################
### Middleware to re-route /search requests to ###
###   v2 methods based upon a feature check    ###
##################################################

class Middleware::SearchV2Router

  def initialize(app)
    @app = app
  end

  def call(env)
    # Routing to V2 code only if account has feature and hits search path
    #
    if(v2_meta = v2_paths[env['PATH_INFO']])
      account_id        = ShardMapping.lookup_with_domain(env['HTTP_HOST']).try(:account_id).to_i
      es_v2             = LaunchParty.new.launched?(feature: v2_meta[:feature], account: account_id)

      env['PATH_INFO']  = v2_meta[:path] if es_v2
    
    # Dirty hack. Couldnt think of another way yet.
    #
    elsif(v2_meta = param_based_v2_paths.detect { |path, values| env['PATH_INFO'].include?(path) })
      account_id        = ShardMapping.lookup_with_domain(env['HTTP_HOST']).try(:account_id).to_i
      es_v2             = LaunchParty.new.launched?(feature: v2_meta[1][:feature], account: account_id)
      
      env['PATH_INFO']  = env['PATH_INFO'].gsub(v2_meta[0], v2_meta[1][:path]) if es_v2
    end
    
    @app.call(env)
  end


  private

    # Add new search paths to this
    #
    def v2_paths
      @@v2_paths ||= {
                                  ### Agent side spotlight search path ###        
        '/search/home/suggest'              => { path: '/search/v2/suggest',                  feature: :esv2_agent_spotlight },
        '/search/all'                       => { path: '/search/v2/spotlight/all',            feature: :esv2_agent_spotlight },
                                  ### Agent side paned search paths ###
        '/search/tickets'                   => { path: '/search/v2/spotlight/tickets',        feature: :esv2_agent_ticket },
        '/search/customers'                 => { path: '/search/v2/spotlight/customers',      feature: :esv2_agent_customer },
        '/search/forums'                    => { path: '/search/v2/spotlight/forums',         feature: :esv2_agent_forum },
        '/search/solutions'                 => { path: '/search/v2/spotlight/solutions',      feature: :esv2_agent_solution },
                                ### Customer side spotlight search paths ###
        '/support/search'                   => { path: '/support/search_v2/all',              feature: :esv2_portal_spotlight },
        '/support/search/tickets'           => { path: '/support/search_v2/tickets',          feature: :esv2_portal_ticket },
        '/support/search/topics'            => { path: '/support/search_v2/topics',           feature: :esv2_portal_forum },
        '/support/search/solutions'         => { path: '/support/search_v2/solutions',        feature: :esv2_portal_solution },
                                  ### Agent side autocomplete paths ###
        '/search/autocomplete/requesters'   => { path: '/search/v2/autocomplete/requesters',  feature: :esv2_user_autocomplete },
        '/search/autocomplete/agents'       => { path: '/search/v2/autocomplete/agents',      feature: :esv2_agent_autocomplete },
        '/search/autocomplete/companies'    => { path: '/search/v2/autocomplete/companies',   feature: :esv2_company_autocomplete },
        '/search/autocomplete/tags'         => { path: '/search/v2/autocomplete/tags',        feature: :esv2_tag_autocomplete },
                                      ### Merge topics search path ###
        '/search/merge_topic'               => { path: '/search/v2/merge_topics/search_topics', feature: :esv2_merge_topic }
      }
    end
    
    def param_based_v2_paths
      @@param_paths ||= {
        '/search/related_solutions/ticket'  => { path: '/search/v2/related_solutions/ticket', feature: :esv2_related_solutions },
        '/search/search_solutions/ticket'   => { path: '/search/v2/search_solutions/ticket',  feature: :esv2_search_solutions },
        '/search/tickets/filter'            => { path: '/search/v2/tickets/filter',           feature: :esv2_merge_ticket }
      }
    end

end
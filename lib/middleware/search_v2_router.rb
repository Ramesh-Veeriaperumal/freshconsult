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
    end

    @app.call(env)
  end


  private

    # Add new search paths to this
    #
    def v2_paths
      @@v2_paths ||= {
                                  ### Agent side spotlight search path ###        
        '/search/home/suggest'      => { path: '/search/v2/suggest',              feature: :esv2_agent_spotlight },
        '/search/all'               => { path: '/search/v2/spotlight/all',        feature: :esv2_agent_spotlight },
                                  ### Agent side paned search paths ###
        '/search/tickets'           => { path: '/search/v2/spotlight/tickets',    feature: :esv2_agent_ticket },
        '/search/customers'         => { path: '/search/v2/spotlight/customers',  feature: :esv2_agent_customer },
        '/search/forums'            => { path: '/search/v2/spotlight/forums',     feature: :esv2_agent_forum },
        '/search/solutions'         => { path: '/search/v2/spotlight/solutions',  feature: :esv2_agent_solution },
                                ### Customer side spotlight search paths ###
        '/support/search'           => { path: '/support/search_v2/all',          feature: :esv2_portal_spotlight },
        '/support/search/tickets'   => { path: '/support/search_v2/tickets',      feature: :esv2_portal_ticket },
        '/support/search/topics'    => { path: '/support/search_v2/topics',       feature: :esv2_portal_forum },
        '/support/search/solutions' => { path: '/support/search_v2/solutions',    feature: :esv2_portal_solution }
      }
    end

end
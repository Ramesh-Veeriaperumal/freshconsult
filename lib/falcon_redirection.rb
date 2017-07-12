class FalconRedirection

  class << self

    include Redis::OthersRedis
    include Redis::RedisKeys

    TICKET_SHOW_PATH_REGEX = /^\/helpdesk\/tickets\/(\d+)$/
    TICKET_EDIT_PATH_REGEX = /^\/helpdesk\/tickets\/(\d+)\/edit$/

    def falcon_redirect(options)
      @options = options
      prevent_redirect = options.key?(:prevent_redirect) ? options[:prevent_redirect] : prevent_redirection
      result = prevent_redirect ? { redirect: false } : {
                                                          redirect: true,
                                                          path: falcon_redirection_path
                                                        }
      return result
    end

    def prevent_redirection
      (falcon_whitelisted_path? || iframe_path? || @options[:is_ajax] ||
        @options[:not_html] || non_falcon_referer?)
    end

    def falcon_whitelisted_path?
      falcon_whitelisted_paths.include?(@options[:path_info]) || @options[:path_info].start_with?('/support')
    end

    def falcon_whitelisted_paths
      ['/enable_falcon', '/disable_falcon', '/admin/widget_config', '/logout', '/support/login'] + get_all_members_in_a_redis_set(FALCON_REDIRECTION_WHITELISTED_PATHS)
    end

    def iframe_path?
      map_url.start_with?('/a/') && check_pathlist
    end

    def non_falcon_referer?
      current_referer && !(current_referer.start_with?('/a/') || current_referer.start_with?('/support'))
    end

    def current_referer
      request_referer = @options[:request_referer]
      URI.parse(request_referer).path if request_referer
    end

    def falcon_redirection_path
      check_tickets_show_path(map_url) || FalconUiRouteMapping[map_url] || check_re_routes ||
        get_others_redis_hash_value(FALCON_REDIRECTION_ROUTE_MAPPINGS, map_url) || prefix_falcon_path
    end

    def check_tickets_show_path(ref_path)
      return unless ref_path.start_with?('/helpdesk/tickets/')
      if (ref_path =~ TICKET_SHOW_PATH_REGEX) ||
         (ref_path =~ TICKET_EDIT_PATH_REGEX)
        return '/a/tickets/' + $1
      end
    end

    def map_url
      current_referer || @options[:env_path]
    end

    def check_re_routes
      get_re_route(map_url)
    end

    def get_re_route(s_key)
      FalconUiReRouteMapping.each do |key, value|
        r_key = key.is_a?(Regexp) ? key : Regexp.new(key)
        return value if r_key =~ s_key
      end
      return
    end

    def prefix_falcon_path
      map_url.start_with?('/a/') ? map_url : ('/a' + map_url)
    end

    def req_referer
      URI.parse(@options[:request_referer]).request_uri
    end

    def check_pathlist
      iframe_paths.include?(map_url) || match_re_iframe(map_url)
    end

    def match_re_iframe(path)
      iframe_re_paths.each { |re| return true if Regexp.new(re) =~ path}
      return false
    end

    def iframe_paths
      ['/a/admin/', '/a/forums/', '/a/social/', '/a/solutions/', '/a/reports/', '/a/contacts/new', '/a/companies/new'] + get_all_members_in_a_redis_set(FALCON_REDIRECTION_IFRAME_PATHS)
    end

    def iframe_re_paths
      ['^/a/contacts/\d+', '^/a/companies/\d+', '^/a/forums/topics/\d+'].freeze
    end

  end

end
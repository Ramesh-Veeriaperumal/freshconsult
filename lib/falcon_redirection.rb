class FalconRedirection

  class << self

    TICKET_SHOW_PATH_REGEX = /^\/helpdesk\/tickets\/(\d+)$/
    TICKET_EDIT_PATH_REGEX = /^\/helpdesk\/tickets\/(\d+)\/edit$/

    IFRAME_PATHS = ['/a/admin/', '/a/forums/', '/a/social/', '/a/solutions/', '/a/reports/', '/a/contacts/new',
                    '/a/companies/new', '/a/sla_policies/', '/a/scenario_automations/', '/a/canned_responses/'].freeze

    IFRAME_RE_PATHS = ['^/a/contacts/\d+', '^/a/companies/\d+', '^/a/forums/.*', '^/a/solutions/.*',
                        '^/a/sla_policies/\d+/edit', '^/a/tickets/\d+', '^/a/agents/\d+'].freeze

    DYNAMIC_PATHS = {
                      /^\/helpdesk\/tickets\/(\d+)/ => '/a/tickets/:id',
                      /^\/helpdesk\/tickets\/archived\/(\d+)/ => '/a/tickets/:id',
                      /^\/helpdesk\/scenario_automations\/(\d+)\/edit/ => '/a/scenario_automations/:id/edit',
                      # /^\/helpdesk\/tickets\/(\d+)\/edit$/ => '/a/tickets/:id',
                      /^\/solution\/articles\/(\d+)\/([a-z]*)/ => '/a/solutions/articles/:id/:language',
                      /^\/solution\/articles\/(\d+)/ => '/a/solutions/articles/:id',
                      /^\/discussions\/topics\/(\d+)/ => '/a/forums/topics/:id',
                      /^\/users\/(\d+)/ => '/a/contacts/:id',
                      /^\/contacts\/(\d+)/ => '/a/contacts/:id',
                      /^\/solution\/folders\/(\d+)/ => '/a/solutions/folders/:id',
                      /^\/solution\/categories\/(\d+)/ => '/a/solutions/categories/:id',
                      /^\/discussions\/(\d+)/ => '/a/forums/categories/:id',
                      /^\/discussions\/forums\/(\d+)/ => '/a/forums/folders/:id',
                      /^\/groups\/(\d+)\/edit/ => '/a/admin/groups/:id/edit',
                      /^\/admin\/va_rules\/(\d+)\/edit/ => '/a/admin/va_rules/:id/edit',
                      /^\/admin\/supervisor_rules\/(\d+)\/edit/ => '/a/admin/supervisor_rules/:id/edit',
                      /^\/admin\/observer_rules\/(\d+)\/edit/ => '/a/admin/observer_rules/:id/edit'
    }.freeze

    SOCIAL_STREAMS_PATH = ['admin/social/facebook_streams','admin/social/twitter_streams','integrations/slack_v2/add_slack_agent','integrations/slack_v2/new'].freeze

    def falcon_redirect(options)
      @options = options
      prevent_redirect = options.key?(:prevent_redirect) ? options[:prevent_redirect] : prevent_redirection
      result = prevent_redirect ? { redirect: false } : {
                                                          redirect: true,
                                                          path: falcon_redirection_path(map_url)
                                                        }
      log_referer(options) if prevent_redirect

      return result
    end

    def log_referer(options)
      logger.debug "a=#{Account.current.try(:id)}, u=#{User.current.try(:id)} rfr=#{options[:request_referer]}, p=#{options[:path_info]}, h=#{!options[:not_html]}, aj=#{options[:is_ajax]}, uuid=#{Thread.current[:message_uuid]}, d=#{options[:domain]}, c=#{options[:controller]}, act=#{options[:action]}"
    end

    def prevent_redirection
      # falcon_whitelisted_path? ||
      iframe_path? || @options[:is_ajax] || @options[:not_html] || non_falcon_referer?
    end

    def falcon_whitelisted_path?
      falcon_whitelisted_paths.include?(@options[:path_info]) || falcon_whitelisted_re_paths || @options[:path_info].start_with?('/support')
    end

    def falcon_whitelisted_paths
      ['/enable_falcon', '/admin/widget_config', '/logout', '/support/login', '/inline/attachment']
    end

    def falcon_whitelisted_re_paths
      whitelisted_re_paths = ['^/download_file/', '^/reports/scheduled_exports/\d+/download_file', '^/helpdesk/attachments/\d+']
      whitelisted_re_paths.each { |re_path| return true if @options[:path_info] =~ Regexp.new(re_path) }
      return false
    end

    def iframe_path?
      map_url.start_with?('/a/') && (check_pathlist || ('/a/' + @options[:path_info]).include?(map_url))
    end

    def non_falcon_referer?
      current_referer && !current_referer.start_with?('/a/', '/support')
    end

    def current_referer
      request_referer = @options[:request_referer] ? URI.parse(@options[:request_referer]).path : nil
      request_referer unless request_referer.to_s.start_with?('/support/')
    end

    def falcon_redirection_path(curr_path,query_string = '')
      check_member_paths(curr_path)  || append_query_string_to_url(curr_path, query_string)||FalconUiRouteMapping[curr_path] || check_re_routes(curr_path) || prefix_falcon_path(curr_path)
    end

    def check_member_paths(ref_path)
      DYNAMIC_PATHS.each do |k,v|
        if ref_path =~ k
          id, language = $1, $2
          result_path = v.sub(':id', id)
          result_path = result_path.sub(':language', language) if language
          return result_path
        end
      end
      false
    end

    def map_url
      current_referer || @options[:env_path]
    end

    def check_re_routes(curr_path)
      get_re_route(curr_path)
    end

    def get_re_route(s_key)
      FalconUiReRouteMapping.each do |key, value|
        r_key = key.is_a?(Regexp) ? key : Regexp.new(key)
        return value if r_key =~ s_key
      end
      return
    end

    def prefix_falcon_path(curr_path)
      curr_path.start_with?('/a/') ? curr_path : ('/a' + curr_path)
    end

    def req_referer
      URI.parse(@options[:request_referer]).request_uri
    end

    def check_pathlist
      IFRAME_PATHS.include?(map_url) || match_re_iframe(map_url)
    end

    def match_re_iframe(path)
      IFRAME_RE_PATHS.each { |re| return true if Regexp.new(re) =~ path}
      return false
    end

    def social_redirect_check?(curr_path)
      SOCIAL_STREAMS_PATH.inject(false) { |skip_social, social_path| skip_social || curr_path.include?(social_path) }
    end

    def append_query_string_to_url(curr_path, query_string)
      if social_redirect_check?(curr_path) && !curr_path.start_with?('/a/')
        query_string.blank? ? '/a' + curr_path : '/a' + curr_path + '?' + query_string
      end
    end
  end

  def self.log_path
    Rails.root.join('log', 'falcon_redirection.log').to_path
  end

  def self.logger
    @logger ||= Logger.new(log_path)
  end
end

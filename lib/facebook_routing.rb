require 'routing_filter/filter'

module RoutingFilter
  class Facebook < Filter 

    def around_recognize(path, env, &block)
      source = nil
      path.sub! %r(^/(facebook)(?=/support|/sso)) do source = $1; '' end
      @support_portal_filter_type = source
      returning yield do |params|
        if source
          params[:portal_type] = source
        end
      end
    end

    def around_generate(*args, &block)
      source = @support_portal_filter_type
      returning yield do |result|
        if source and !exclude_path?(result)
          result.sub!(%r(^(http.?://[^/]*)?(.*))){ "#{$1}/#{source}#{$2}" }
        end 
      end
    end

    def exclude_path? result
      (%r(/profile_image)).match(result)
    end

  end
end
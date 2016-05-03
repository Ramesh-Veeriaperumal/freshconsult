require 'routing_filter/filter'

module RoutingFilter
  class Locale < Filter
    
    def around_recognize(path, env, &block)
      locale = @url_locale = nil
      path.sub! %r(^/([a-zA-Z]{2}|[a-zA-Z]{2}-[a-zA-Z]{2})(?=#{accepted_paths.join('|')})) do locale = $1; '' end        
      if path.starts_with?(*accepted_paths)
        yield.tap do |params|
          params[:url_locale] = @url_locale = locale 
        end
      end
    end

    def around_generate(*args, &block)
      url_locale = args.first.delete(:url_locale) || @url_locale
      yield.tap do |result|
        url = result.is_a?(Array) ? result.first : result
        if url.starts_with?(*accepted_paths) && url_locale.present?
          url.sub!(%r(^(http.?://[^/]*)?(.*))){ "#{$1}/#{url_locale}#{$2}" }
        end
      end
    end

    def accepted_paths
      ['/support', '/register', '/activate', '/password_resets']
    end
  end
end

require 'routing_filter/filter'

module RoutingFilter
  class Locale < Filter

    def around_recognize(path, env, &block)
      locale = nil
      path.sub! %r(^/([a-zA-Z]{2}|[a-zA-Z]{2}-[a-zA-Z]{2})(?=/support)) do locale = $1; '' end
      if path.starts_with?('/support')
        yield.tap do |params|
          params[:url_locale] = @url_locale = locale 
        end
      end
    end

    def around_generate(*args, &block)
      yield.tap do |result|
        url = result.is_a?(Array) ? result.first : result
        if url.starts_with?('/support') && @url_locale.present?
          url.sub!(%r(^(http.?://[^/]*)?(.*))){ "#{$1}/#{@url_locale}#{$2}" }
        end
      end
    end
  end
end

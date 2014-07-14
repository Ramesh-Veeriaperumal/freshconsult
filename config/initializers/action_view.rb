module ActionView
  module Helpers
    module UrlHelper
      include JavaScriptHelper

      def url_for(options = {})
        options ||= {}
        url = case options
        when String
          escape = true
          options
        when Hash
          options = { :only_path => options[:host].nil? }.update(options.symbolize_keys)
          escape  = options.key?(:escape) ? options.delete(:escape) : true
          @controller.send(:url_for, options)
        when :back
          escape = false
          if @controller.request.env["HTTP_REFERER"] 
		if @controller.request.env["HTTP_REFERER"].downcase.include? "javascript:"
                  "javascript:alert('Invalid Referer Passed.')"
		else
                  @controller.request.env["HTTP_REFERER"]
		end
          else
            'javascript:history.back()'
          end
        else
          escape = false
          polymorphic_path(options)
        end
        escape ? escape_once(url).html_safe : url
      end

    end
  end
end

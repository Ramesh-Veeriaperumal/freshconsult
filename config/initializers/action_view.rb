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
		referer = @controller.request.env["HTTP_REFERER"]
                invalid_referer = '/'
                invalid_referer = "javascript:alert('Invalid Referer.')"
		if referer.downcase.include? "javascript:"
                  invalid_referer
		elsif referer.downcase.include? "script"
                  invalid_referer
		elsif referer.include? "&#"
                  invalid_referer
		elsif referer.downcase.include? '&lt;'
                  invalid_referer
		elsif referer.downcase.include? '&gt;'
                  invalid_referer
		elsif referer.downcase.start_with? 'http://'
                  referer
		elsif referer.downcase.start_with? 'https://'
                  referer
		elsif referer.downcase.start_with? '/'
                  referer
		else
                  invalid_referer
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

require 'rails_sanitizer'
module HtmlSanitizer
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def xss_sanitize(options={})
      class_attribute :xss_terminate_options
      self.xss_terminate_options = {
        :only => (options[:only]||[]),
        :html_sanitize => (options[:html_sanitize] || []),
        :full_sanitizer => (options[:full_sanitizer] || []),
        :plain_sanitizer => (options[:plain_sanitizer] || []),
        :article_sanitizer => (options[:article_sanitizer] || []),
        :post_sanitizer => (options[:post_sanitizer] || []),
        :decode_calm_sanitizer => (options[:decode_calm_sanitizer] || []),
        :cannedresponse_sanitizer => (options[:cannedresponse_sanitizer] || [])
      }
      
      begin
        xss_terminate_options[:only].each do |field|
          handle_sanitization(xss_terminate_options, field)
        end
      rescue Exception => e
        
      end

    end
    
    def handle_sanitization(xss_terminate_options,column)
      if xss_terminate_options[:full_sanitizer].include?(column)
        generate_setters_full_sanitizer(column)
      elsif xss_terminate_options[:html_sanitize].include?(column)
        generate_setters_html_sanitizer(column)
      elsif xss_terminate_options[:plain_sanitizer].include?(column)
        generate_setters_plain_sanitizer(column)
      elsif xss_terminate_options[:article_sanitizer].include?(column)
        generate_setters_article_sanitizer(column)
      elsif xss_terminate_options[:post_sanitizer].include?(column)
        generate_setters_post_sanitizer(column)
      elsif xss_terminate_options[:decode_calm_sanitizer].include?(column)
        generate_setters_decode_calm_sanitizer(column, 'sanitize_article')
      elsif xss_terminate_options[:cannedresponse_sanitizer].include?(column)
        generate_setters_decode_calm_sanitizer(column, 'clean')
      else
        generate_setters_plain(column)
      end
    end

    def generate_setters_html_sanitizer(attr_name)
      class_eval %Q(
        def #{attr_name.to_s}=(value)
          write_attribute("#{attr_name.to_sym}",Helpdesk::HTMLSanitizer.clean(value))
        end
      )
    end
    def generate_setters_full_sanitizer(attr_name)
      class_eval %Q(
        def #{attr_name.to_s}=(value)
          write_attribute("#{attr_name.to_sym}",CGI.escapeHTML(value))
        end
      )
    end
    def generate_setters_plain_sanitizer(attr_name)
      class_eval %Q(
        def #{attr_name.to_s}=(value)
          write_attribute("#{attr_name.to_sym}",RailsFullSanitizer.sanitize(value))
        end
      )
    end
    def generate_setters_plain(attr_name)
      class_eval %Q(
        def #{attr_name.to_s}=(value)
          write_attribute("#{attr_name.to_sym}",RailsSanitizer.full_sanitizer.sanitize(value))
        end
      )
    end

    def generate_setters_article_sanitizer(attr_name)
      class_eval %Q(
        def #{attr_name.to_s}=(value)
          write_attribute("#{attr_name.to_sym}",Helpdesk::HTMLSanitizer.sanitize_article(value))
        end
      )
    end

    def generate_setters_post_sanitizer(attr_name)
      class_eval %Q(
        def #{attr_name.to_s}=(value)
          write_attribute("#{attr_name.to_sym}",Helpdesk::HTMLSanitizer.sanitize_post(value))
        end
      )
    end

    def generate_setters_decode_calm_sanitizer(attr_name, html_sanitizer_method)
      class_eval %Q(
        def #{attr_name.to_s}=(value)
          value = value.is_a?(String) ? Helpdesk::HTMLSanitizer.#{html_sanitizer_method}(value).gsub('%7B','{').gsub('%7D','}') : value
          write_attribute("#{attr_name.to_sym}",value)
        end
        )
    end

  end

end

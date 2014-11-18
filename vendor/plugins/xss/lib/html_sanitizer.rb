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
        :plain_sanitizer => (options[:plain_sanitizer] || [])
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

  end

end

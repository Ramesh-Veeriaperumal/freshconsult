module HtmlSanitizer
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def xss_sanitize(options={})
      class_attribute :xss_terminate_options
      self.xss_terminate_options = {
        :except => (options[:except] || []),
        :only => (options[:only]||[]),
        :html_sanitize => (options[:html_sanitize] || []),
        :full_sanitizer => (options[:full_sanitizer] || [])
      }
      sanitize_field_data
    end

    def sanitize_field_data
      if(xss_terminate_options[:only].empty?)
          self.columns.each do |column|
            next  unless column.type == :text || column.type == :string
            field = column.name.to_sym
            if xss_terminate_options[:except].include?(field)
              next
            else
              handle_sanitization(xss_terminate_options,field)
            end
          end
      else
          self.columns.each do |column|
            next  unless column.type == :text || column.type == :string
            field = column.name.to_sym
            if xss_terminate_options[:only].include?(field)
              handle_sanitization(xss_terminate_options,field)
            else
              next
            end
          end
      end
    end

    def handle_sanitization(xss_terminate_options,column)
      if xss_terminate_options[:full_sanitizer].include?(column)
        generate_setters_full_sanitizer(column)
      elsif xss_terminate_options[:html_sanitize].include?(column)
        generate_setters_html_sanitizer(column)
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
    def generate_setters_plain(attr_name)
      class_eval %Q(
        def #{attr_name.to_s}=(value)
          write_attribute("#{attr_name.to_sym}",RailsSanitizer.full_sanitizer.sanitize(value))
        end 
        )
    end

  end

end

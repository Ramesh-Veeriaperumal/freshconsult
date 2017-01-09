# https://github.com/rails/rails/pull/15106 Fix for transactional callbacks to execute in same order
module ActiveRecord
  module Transactions
    extend ActiveSupport::Concern

    module ClassMethods
      def after_commit(*args, &block)
        options = args.last
        if options.is_a?(Hash) && options[:on]
          options[:if] = ["transaction_include_action?(:#{options[:on]})"].concat(Array.wrap(options[:if]))
        end
        options[:prepend] = true if options.is_a?(Hash)
        args << { prepend: true } unless options.is_a?(Hash)
        set_callback(:commit, :after, *args, &block)
      end

      # This callback is called after a create, update, or destroy are rolled back.
      #
      # Please check the documentation of +after_commit+ for options.
      def after_rollback(*args, &block)
        options = args.last
        if options.is_a?(Hash) && options[:on]
          options[:if] = ["transaction_include_action?(:#{options[:on]})"].concat(Array.wrap(options[:if]))
        end
        options[:prepend] = true if options.is_a?(Hash)
        args << { prepend: true } unless options.is_a?(Hash)
        set_callback(:rollback, :after, *args, &block)
      end
    end
  end
end

#https://github.com/rails/rails/issues/3205, showing exception trace for transacational callbacks
module Foo
  module CommittedWithExceptions
    def committed!
      super
    rescue Exception => e # same as active_record/connection_adapters/abstract/database_statements.rb:370
      logger.error e.message + "\n " + e.backtrace.join("\n ")
      raise
    end
  end
end
 
ActiveRecord::Base.send(:include, Foo::CommittedWithExceptions)

# for rails 3 rendering a hidden input tag with nil value to update the attr, if no input is given
module ActionView
  module Helpers
    module FormHelper
      def check_box(object_name, method, options = {}, checked_value = "1", unchecked_value = "0")
        InstanceTag.new(object_name, method, self, 
                        options.delete(:object)).to_check_box_tag(options, checked_value.to_s, unchecked_value.to_s)
      end
    end

    class InstanceTag
      def select_content_tag(option_tags, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        select = content_tag("select", add_options(option_tags, options, value(object)), html_options)
        select
      end
    end
  end
end

# In Rails 3. submit button we are not getting id.This method is for QA Automation
module ActionView
  module Helpers
    class FormBuilder
      def submit(value=nil, options={})
        value, options = nil, value if value.is_a?(Hash)
        value ||= submit_default_value
        @template.submit_tag(value, options.reverse_merge(:id => "#{object_name}_submit"))
      end
    end
  end
end

# TODO:RAILS-SESSION-SHARING remove below code only fully migrate to Rails3
module ActionController
  module Flash
    class FlashHash < Hash
      def method_missing(m, *a, &b)
      end
    end
  end
end

ActiveModel::Errors.class_eval do
  def fd_json(options=nil)
    a = []
    to_hash.map do |key, values|
      values.each do |val|
        a << [key.to_s, val]
      end
    end
    a.to_json
  end
end

#https://github.com/rack/rack/issues/718. 
#Issue got fixed in rack 1.5.2 but sctionpack is depended on that so we can't upgrade
#So, monkey patching the same thing
module Rack
  module Multipart
    class Parser
      def get_filename(head)
        filename = nil
        case head
        when Rack::Multipart::RFC2183
          filename = Hash[head.scan(Rack::Multipart::DISPPARM)]['filename']
          filename = $1 if filename and filename =~ /^"(.*)"$/
        when Rack::Multipart::BROKEN_QUOTED, Rack::Multipart::BROKEN_UNQUOTED
          filename = $1
        end

        return unless filename

        if filename.scan(/%.?.?/).all? { |s| s =~ /%[0-9a-fA-F]{2}/ }
          filename = Rack::Utils.unescape(filename)
        end

        scrub_filename filename

        if filename !~ /\\[^\\"]/
          filename = filename.gsub(/\\(.)/, '\1')
        end
        filename
      end

      if "<3".respond_to? :valid_encoding?
        def scrub_filename(filename)
          unless filename.valid_encoding?
            # FIXME: this force_encoding is for Ruby 2.0 and 1.9 support.
            # We can remove it after they are dropped
            filename.force_encoding(Encoding::ASCII_8BIT)
            filename.encode!(:invalid => :replace, :undef => :replace)
          end
        end
      else
        def scrub_filename(filename)
        end
      end

    end
  end
end


#https://github.com/rails/rails/pull/17978
# Fix for append_info_to_payload not getting called during exception 
module ActionController
  module Instrumentation
    def process_action(*args)
      raw_payload = {
        :controller => self.class.name,
        :action     => self.action_name,
        :params     => request.filtered_parameters,
        :format     => request.format.try(:ref),
        :method     => request.request_method,
        :path       => (request.fullpath rescue "unknown")
      }

      ActiveSupport::Notifications.instrument("start_processing.action_controller", raw_payload.dup)

      ActiveSupport::Notifications.instrument("process_action.action_controller", raw_payload) do |payload|
        begin
          result = super
          payload[:status] = response.status
          result
        ensure
          append_info_to_payload(payload)
        end
      end
    end
  end
end
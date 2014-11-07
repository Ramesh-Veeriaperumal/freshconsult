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
      def to_select_tag(choices, options, html_options)# fix for multiselect returning [] if nothing is selected
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object)
        selected_value = options.has_key?(:selected) ? options[:selected] : value
        disabled_value = options.has_key?(:disabled) ? options[:disabled] : nil
        content_tag("select", add_options(options_for_select(choices, :selected => selected_value, 
          :disabled => disabled_value), options, selected_value), html_options)
      end
    end
  end
end

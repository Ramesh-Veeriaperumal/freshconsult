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
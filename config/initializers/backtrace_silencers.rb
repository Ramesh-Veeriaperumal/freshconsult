# Be sure to restart your server when you modify this file.

# You can add backtrace silencers for libraries that you're using but don't wish to see in your backtraces.
# Rails.backtrace_cleaner.add_silencer { |line| line =~ /my_noisy_library/ }

# You can also remove all the silencers if you're trying to debug a problem that might stem from framework code.
# Rails.backtrace_cleaner.remove_silencers!


# https://github.com/rails/rails/pull/15106 Fix for transactional callbacks to execute in same order
module ActiveRecord
  module Transactions
    extend ActiveSupport::Concern

    module ClassMethods
      def after_commit(*args, &block)
        options = args.last
        if options.is_a?(Hash) && options[:on]
          options[:if] = Array.wrap(options[:if])
          options[:prepend] = true
          options[:if] << "transaction_include_action?(:#{options[:on]})"
        end
        set_callback(:commit, :after, *args, &block)
      end

      # This callback is called after a create, update, or destroy are rolled back.
      #
      # Please check the documentation of +after_commit+ for options.
      def after_rollback(*args, &block)
        options = args.last
        if options.is_a?(Hash) && options[:on]
          options[:if] = Array.wrap(options[:if])
          options[:prepend] = true
          options[:if] << "transaction_include_action?(:#{options[:on]})"
        end
        set_callback(:rollback, :after, *args, &block)
      end
    end
  end
end
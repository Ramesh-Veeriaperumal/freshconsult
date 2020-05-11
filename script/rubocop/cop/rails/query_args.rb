# frozen_string_literal: true

module RuboCop
  module Cop
    module Rails
      class QueryArgs < Cop
        # This cop checks for scope calls where it was passed
        # a method (usually a scope) instead of a lambda/proc.
        #
        # @example
        #
        #   # bad
        #   scope :something, where(something: true)
        #   # good
        #   scope :something, -> { where(something: true) }
        #
        #   # bad
        #   scope :something, :conditions => { active: false }, :order => "something"
        #   # good
        #   scope :something, -> { where(active: true).order(something) }
        #
        #   # bad
        #   scope :something, :include => { something: false }, :select => "something"
        #   # good
        #   scope :something, -> { includes(something: true).select(something) }

        MSG = 'Use `lambda`/`proc` with method chaining instead of a plain method call with key-value for conditions, orders, group, join, select, limit, offset and include. Ref: <a href="https://github.com/freshdesk/helpkit/blob/107d8709231df7bc8bf107569628715ebfa57e9d/script/rubocop/cop/readme.md#railsqueryargs">New syntax</a>'.freeze

        def_node_matcher :query?, '(hash <$(pair (sym {:conditions :order :include :join :joins :group :select :limit :offset}) !nil) ...>)'

        def on_send(node)
          return nil unless [:scope, :count, :sum, :all].include?(node.method_name.to_sym)

          node.arguments.each do |args|
            if args.respond_to?(:method_name) && args.method_name.to_sym == :lambda
              args.to_a.each do |opt|
                query?(opt) do |second_arg|
                  add_offense(second_arg)
                end
              end
            else
              query?(args) do |second_arg|
                add_offense(second_arg)
              end
            end
          end
        end
      end
    end
  end
end

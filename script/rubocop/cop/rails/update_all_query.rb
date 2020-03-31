# frozen_string_literal: true

module RuboCop
  module Cop
    module Rails
      class UpdateAllQuery < Cop
        # This cop checks conditionally queries in update all
        #
        # @example
        #
        #   # bad
        #   User.update_all({name: 'test'},{name: 'test1'})
        #   # good
        #   User.where(name: 'test1').update_all(name: 'test')

        MSG = 'Avoid query in `update_all` method. Ref: <a href="https://github.com/freshdesk/helpkit/blob/107d8709231df7bc8bf107569628715ebfa57e9d/script/rubocop/cop/readme.md#railsupdateallquery">New syntax</a>'.freeze

        def on_send(node)
          return nil if node.method_name.to_sym != :update_all

          add_offense(node.arguments.last) if node.arguments.length > 1
        end
      end
    end
  end
end


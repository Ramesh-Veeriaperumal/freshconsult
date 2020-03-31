# frozen_string_literal: true

module RuboCop
  module Cop
    module Rails
      class JsonGenerate < Cop
        # This cop checks for JSON.Generate usage.
        #
        # @example
        #
        #   # bad
        #   JSON.generate(something)
        #
        #   # good
        #   something.to_json

        MSG = 'Use `to_json` instead of `JSON.generate`. Ref: <a href="https://github.com/freshdesk/helpkit/blob/107d8709231df7bc8bf107569628715ebfa57e9d/script/rubocop/cop/readme.md#railsjsongenerate">New syntax</a>'.freeze

        def_node_matcher :json_generate?, '(send $(const nil? :JSON) :generate (...))'

        def on_send(node)
          json_generate?(node) do |second_arg|
            add_offense(second_arg)
          end
        end
      end
    end
  end
end


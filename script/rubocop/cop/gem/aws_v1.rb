# frozen_string_literal: true

module RuboCop
  module Cop
    module Gem
      class AwsV1 < Cop
        # This cop checks for v1 client usage.
        #
        # @example
        #
        #   # bad
        #   AWS::SNS.new.client(...)
        #   # good
        #   Aws::SNS::Client.new(...)

        MSG = 'Use `Aws::` SDK client instead of V1 Client `AWS::`. Ref: <a href="https://github.com/freshdesk/helpkit/blob/107d8709231df7bc8bf107569628715ebfa57e9d/script/rubocop/cop/readme.md#gemawsv1">New syntax</a>'.freeze

        def_node_matcher :v1?, '(send $(const (const nil? :AWS) _) ...)'

        def on_send(node)
          v1?(node) do |second_arg|
            add_offense(second_arg)
          end
        end
      end
    end
  end
end


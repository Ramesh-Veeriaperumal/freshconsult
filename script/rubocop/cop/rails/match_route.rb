# frozen_string_literal: true

module RuboCop
  module Cop
    module Rails
      class MatchRoute < Cop
        # Routes using match must specify the request method
        #
        # bad
        # match '/' => 'root#index'
        #
        # good
        # match '/' => 'root#index', via: :get
        # get '/' => 'root#index'

        MSG = 'Routes using `match` must be specified with the request method, Ref: <a href="https://github.com/freshdesk/helpkit/blob/107d8709231df7bc8bf107569628715ebfa57e9d/script/rubocop/cop/readme.md#railsmatchroute">New syntax</a>'.freeze

        def_node_matcher :match_route?, '(hash <$(pair (sym :via) !nil) ...>)'

        def on_send(node)
          return nil if node.method_name.to_sym != :match

          valid = false
          node.arguments.each do |args|
            match_route?(args) do |second_arg|
              valid = true
            end
          end
          add_offense(node, message: MSG) unless valid
        end
      end
    end
  end
end


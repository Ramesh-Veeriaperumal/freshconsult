# frozen_string_literal: true

module RuboCop
  module Cop
    module Rails
      class FinderMethod < Cop
        # This cop checks `find` methods. Finder methods which previously accepted "finder options" eg: find(:all), no longer do.
        # Also all dynamic methods except for find_by_... and find_by_...! are deprecated
        #
        # @example
        #   # bad
        #   User.find(:all, ...)
        #   # good
        #   User.where(...)
        #
        #   # bad
        #   User.find_all_by_...(...)
        #   # good
        #   User.where(...)
        #
        #   # bad
        #   User.find_last_by_...(...)
        #   # good
        #   User.where(...).last
        #
        #   # bad
        #   User.scoped_by_...(...)
        #   # good
        #   User.where(...)
        #
        #   # bad
        #   User.find_or_initialize_by_...(...)
        #   # good
        #   User.find_or_initialize_by(...)
        #
        #   # bad
        #   User.find_or_create_by_...(...)
        #   # good
        #   User.find_or_create_by(...)
        #
        #   # bad
        #   Topic.paginate_by_forum_id(id, order: 'something desc', page: page)
        #   # good
        #   Topic.where(forum_id: id).order('something desc').paginate(page: page)

        MSG = 'Use `%{static_name}` instead of dynamic `%{method}`. Ref: <a href="https://github.com/freshdesk/helpkit/blob/107d8709231df7bc8bf107569628715ebfa57e9d/script/rubocop/cop/readme.md#railsfindermethod">New syntax</a>'.freeze
        FIND_METHOD_NAME = 'find'.freeze
        FIND_ALL_OPTIONS = ['all', 'first'].freeze
        ERROR_PATTERN = '%{method}(%{arg}...)'.freeze
        FINDER_METHOD_PATTERN = /^((find|scoped|paginate)_((all|last|or_initialize|or_create)_)?by_)(.+?)(!)?$/.freeze
        FINDER_METHOD_ALTERNATE = {
          find: 'where(...) or where(...).first',
          # find_by_: 'where(...).first', # will re-enable after fixing existing one.
          find_all_by_: 'where(...)',
          find_last_by_: 'where(...).last',
          scoped_by_: 'where(...)',
          find_or_initialize_by_: 'where(...).first_or_initialize',
          find_or_create_by_: 'where(...).first_or_create',
          paginate_by_: 'where(...).paginate(...)'
        }.freeze

        def_node_matcher :ignore_language_node?, '(send $(const nil? :Language) {:find_by_code :find_by_codes :find_by_name :find_by_key :find} (...))'

        def_node_matcher :ignore_fresh_id_user_node?, '(send $(const (const (const (const nil? :Freshid) :V2) :Models) :User) {:find_by_email} ...)'

        def_node_matcher :ignore_fresh_id_v1_user_node?, '(send $(const (const nil? :Freshid) :User) {:find_by_email} ...)'

        def_node_matcher :ignore_fresh_id_account_node?, '(send $(const (const (const (const nil? :Freshid) :V2) :Models) :Account) {:find_by_domain} ...)'

        def on_send(node)
          method_name = static_name = nil

          ignore_language_node?(node) do |second_arg|
            return nil
          end

          ignore_fresh_id_user_node?(node) do |second_arg|
            return nil
          end

          ignore_fresh_id_v1_user_node?(node) do |second_arg|
            return nil
          end

          ignore_fresh_id_account_node?(node) do |second_arg|
            return nil
          end

          if find_all_method(node)
            static_name = FINDER_METHOD_ALTERNATE[FIND_METHOD_NAME.to_sym]
            method_name = format(ERROR_PATTERN, method: FIND_METHOD_NAME, arg: ":#{FIND_ALL_OPTIONS.join(' (or) ')},")
          elsif (result = finder_method(node))
            return nil unless FINDER_METHOD_ALTERNATE.keys.include?(result)

            static_name = FINDER_METHOD_ALTERNATE[result]
            method_name = format(ERROR_PATTERN, method: result, arg: nil)
          else
            return nil
          end

          add_offense(node,
                      message: format(MSG, static_name: static_name,
                                           method: method_name))
        end

        def find_all_method(node)
          node.method_name && node.method_name.to_s.eql?(FIND_METHOD_NAME) && node.first_argument && node.first_argument.sym_type? && FIND_ALL_OPTIONS.include?(node.first_argument.value.to_s)
        end

        def finder_method(node)
          (match = FINDER_METHOD_PATTERN.match(node.method_name)) && match && match[1].to_sym
        end
      end
    end
  end
end

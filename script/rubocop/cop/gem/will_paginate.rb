# frozen_string_literal: true

module RuboCop
  module Cop
    module Gem
      class WillPaginate < Cop
        # This cop checks for paginate arguments as latest version restricted to accept only per_page, total_entries and page.
        #
        # @example
        #
        #   # bad
        #   something.paginate(:page => params[:page],:include => [:something],:per_page => 50)
        #   # good
        #   something.includes([:tag_uses]).paginate(:page => params[:page],:per_page => 50)
        #
        #   # bad
        #   something.paginate(:page => params[:page],:order => "updated_at ASC",:per_page => 50)
        #   # good
        #   something.order("updated_at ASC").paginate(:page => params[:page],:per_page => 50)
        #

        MSG = 'Use `:per_page, :page and :total_entries` options alone as arguments for paginate methods. Ref: <a href="https://github.com/freshdesk/helpkit/blob/107d8709231df7bc8bf107569628715ebfa57e9d/script/rubocop/cop/readme.md#gemwillpaginate">New syntax</a>'.freeze

        def_node_matcher :paginate?, '(hash <$(pair (sym {:conditions :order :include :join :joins :group :select :limit :offset}) !nil) ...>)'

        def on_send(node)
          return nil if node.method_name.to_sym != :paginate

          node.arguments.each do |args|
            add_offense(args, message: MSG) unless args.hash_type?
            paginate?(args) do |second_arg|
              add_offense(args)
            end
          end
        end
      end
    end
  end
end


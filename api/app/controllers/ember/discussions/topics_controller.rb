module Ember
  module Discussions
    class TopicsController < ApiDiscussions::TopicsController
      def first_post
        @post = { description: @item.first_post.body_html }
      end
    end
  end
end

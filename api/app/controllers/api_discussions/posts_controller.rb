module ApiDiscussions
  class PostsController < ApiApplicationController
    before_filter :load_topic, only: [:topic_posts]

    def topic_posts
      paginate_items(@item.posts, 'posts')
      render '/api_discussions/posts/post_list'
    end

    private

      def build_object
        super
        @item.user = current_user
        @item.portal = current_portal
        @item.topic_id ||= params[cname]['topic_id']
      end

      def load_topic
        load_object current_account.topics
      end

      def feature_name
        FeatureConstants::DISCUSSION
      end

      def set_custom_errors(_item = @item)
        ErrorHelper.rename_error_fields({ topic: :topic_id }, @item)
      end

      def sanitize_params
        @email = params[cname].delete(:email) if params[cname][:email]
      end

      def validate_params
        fields = "DiscussionConstants::#{action_name.upcase}_POST_FIELDS".constantize
        params[cname].permit(*(fields))
        post = ApiDiscussions::PostValidation.new(params[cname], @item)
        render_errors post.errors, post.error_options unless post.valid?
      end

      def scoper
        current_account.posts
      end
  end
end

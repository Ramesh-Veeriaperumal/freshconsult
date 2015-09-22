module ApiDiscussions
  class PostsController < ApiApplicationController
    before_filter :topic_exists?, only: [:topic_posts]

    def topic_posts
      @posts = paginate_items(@item.posts)
      render '/api_discussions/posts/post_list'
    end

    private

      def build_object
        super
        @item.user = api_current_user
        @item.portal = current_portal
        @item.topic_id ||= params[cname]['topic_id']
        @item.topic = @topic
      end

      def topic_exists?
        load_object current_account.topics
      end

      def load_topic
        @topic = current_account.topics.find_by_id(params[:id].to_i)
        head 404 unless @topic
        @topic
      end

      def feature_name
        FeatureConstants::DISCUSSION
      end

      def validate_params
        return false if create? && !load_topic
        params[cname].permit(*(DiscussionConstants::POST_FIELDS))
        post = ApiDiscussions::PostValidation.new(params[cname], @item)
        render_errors post.errors, post.error_options unless post.valid?
      end

      def scoper
        current_account.posts
      end
  end
end

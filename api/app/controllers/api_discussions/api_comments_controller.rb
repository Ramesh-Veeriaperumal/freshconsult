module ApiDiscussions
  class ApiCommentsController < ApiApplicationController
    before_filter :topic_exists?, only: [:topic_comments]

    def topic_comments
      return if validate_filter_params
      @comments = paginate_items(@item.posts)
      render '/api_discussions/api_comments/comment_list'
    end

    private

      def allowed_to_access?
        # skipping allowed_to_access? for update as different params(body_html & answer) require different privileges.
        update? ? true : super
      end

      def build_object
        super
        @item.user = api_current_user
        @item.portal = current_portal
        @item.topic = @topic
      end

      def topic_exists?
        load_object current_account.topics
      end

      def load_topic
        @topic = current_account.topics.find_by_id(params[:id])
        head 404 unless @topic
        @topic
      end

      def feature_name
        FeatureConstants::DISCUSSION
      end

      def validate_params
        return false if create? && !load_topic
        params[cname].permit(*get_fields("DiscussionConstants::#{action_name.upcase}_COMMENT_FIELDS"))
        comment = ApiDiscussions::ApiCommentValidation.new(params[cname], @item)
        render_errors comment.errors, comment.error_options unless comment.valid?(action_name.to_sym)
      end

      def scoper
        current_account.posts
      end
  end
end

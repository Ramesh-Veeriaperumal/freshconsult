module ApiDiscussions
  class CommentsController < ApiApplicationController
    before_filter :topic_exists?, only: [:topic_comments]

    def topic_comments
      @comments = paginate_items(@item.posts)
      render '/api_discussions/comments/comment_list'
    end

    private

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
        params[cname].permit(*get_fields)
        comment = ApiDiscussions::CommentValidation.new(params[cname], @item)
        render_errors comment.errors, comment.error_options unless comment.valid?
      end

      def get_fields
        if create? || DiscussionConstants::QUESTION_STAMPS.exclude?(@item.topic.stamp_type)
          DiscussionConstants::COMMENT_FIELDS
        else
          DiscussionConstants::UPDATE_COMMENT_FIELDS
        end
      end

      def scoper
        current_account.posts
      end
  end
end

module ApiDiscussions
  class TopicsController < ApiApplicationController
    include DiscussionMonitorConcern
    SLAVE_ACTIONS = %w(index forum_topics).freeze
    decorate_views(decorate_objects: [:followed_by, :forum_topics])

    before_filter :forum_exists?, only: [:forum_topics]
    COLLECTION_RESPONSE_FOR = ['forum_topics'].freeze
    def create
      @item.user = api_current_user
      post = @item.posts.build(params[cname].select { |x| DiscussionConstants::TOPIC_COMMENT_CREATE_FIELDS.flat_map(&:last).include?(x) })
      post.user = api_current_user
      assign_parent post, :topic, @item
      super
    end

    def update
      post = @item.first_post
      post.body_html = params[cname][:body_html] if params[cname].key?(:body_html)
      super
    end

    def forum_topics
      return if validate_filter_params
      @items = paginate_items(@item.topics.newest)
      render '/api_discussions/topics/topic_list'
    end

    def followed_by
      return if validate_filter_params(DiscussionConstants::FOLLOWED_BY_FIELDS)
      @items = paginate_items(current_account.topics.followed_by(params[:user_id]).newest)
      render '/api_discussions/topics/topic_list'
    end

    private

      def forum_exists?
        load_object current_account.forums
      end

      def after_load_object
        # merged source topic could only be shown or deleted.
        # Other actions allowed on this topic are: is_following, topic_comments, adding a new comment.
        render_request_error(:immutable_resource, 403) if !allowed_actions_on_merged_topic? && @item.merged_topic_id.present? && @item.locked?
      end

      def allowed_actions_on_merged_topic?
        show? || destroy?
      end

      def load_forum
        @forum = current_account.forums.find_by_id(params[:id])
        log_and_render_404 unless @forum
        @forum
      end

      def feature_name
        FeatureConstants::DISCUSSION
      end

      def set_custom_errors(_item = @item)
        if @item.errors[:stamp_type].present?
          allowed_string = allowed_stamp_types.join(',')
          @item.errors[:stamp_type] = ErrorConstants::ERROR_MESSAGES[:not_included] % { list: allowed_string }
        end
        ErrorHelper.rename_error_fields({ forum: :forum_id }, @item)
        @error_options = { remove: :posts }
      end

      def allowed_stamp_types
        if @item.forum.forum_type == DiscussionConstants::QUESTION_FORUM_TYPE
          # if forum is of question type, the error may be because stamp_type is not included in the list 'answered, unanswered' (or)
          # 'answered' stamp_type could have been set for a topic with no answers or vice versa.
          DiscussionConstants::FORUM_TO_STAMP_TYPE[@item.forum.forum_type][@item.stamp_type] || DiscussionConstants::QUESTION_STAMPS
        else
          DiscussionConstants::FORUM_TO_STAMP_TYPE[@item.forum.forum_type]
        end
      end

      def sanitize_params
        params[cname][:body_html] = params[cname].delete(:message) if params[cname].key?(:message)
      end

      def assign_parent(item, parent, value)
        if item.has_attribute?(parent.to_sym) # eg: topic has forum_id
          item.send(:write_attribute, parent, value[parent]) if value.key?(parent)
        else
          item.association(parent.to_sym).writer(value) # here topic is not yet saved hence, topic_id cannot be retrieved.
        end
      end

      def assign_protected
        assign_parent @item, :forum, @forum if create?
        assign_parent @item, :forum_id, params[cname]
      end

      def validate_params
        return false if create? && !load_forum
        params[cname].permit(*(get_fields("DiscussionConstants::#{action_name.upcase}_TOPIC_FIELDS")))
        topic = ApiDiscussions::TopicValidation.new(params[cname], @item)
        render_errors topic.errors, topic.error_options unless topic.valid?(action_name.to_sym)
      end

      def scoper
        current_account.topics
      end
  end
end

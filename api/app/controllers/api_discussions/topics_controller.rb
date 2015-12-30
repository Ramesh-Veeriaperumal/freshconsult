module ApiDiscussions
  class TopicsController < ApiApplicationController
    include DiscussionMonitorConcern
    before_filter :forum_exists?, only: [:forum_topics]

    def create
      @item.user = api_current_user
      post = @item.posts.build(params[cname].select { |x| DiscussionConstants::COMMENT_FIELDS.include?(x) })
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
      @topics = paginate_items(@item.topics.newest)
      render '/api_discussions/topics/topic_list'
    end

    def followed_by
      return if validate_filter_params(DiscussionConstants::FOLLOWED_BY_FIELDS)
      @topics = paginate_items(current_account.topics.followed_by(params[:user_id]).newest)
      render '/api_discussions/topics/topic_list'
    end

    private

      def forum_exists?
        load_object current_account.forums
      end

      def load_forum
        @forum = current_account.forums.find_by_id(params[:id])
        head 404 unless @forum
        @forum
      end

      def feature_name
        FeatureConstants::DISCUSSION
      end

      def set_custom_errors(_item = @item)
        if @item.errors[:stamp_type].present?
          allowed_string = get_allowed_stamp_types.join(',')
          @item.errors[:stamp_type] = ErrorConstants::ERROR_MESSAGES[:allowed_stamp_type] % { list: allowed_string }
        end
        ErrorHelper.rename_error_fields({ forum: :forum_id }, @item)
        @error_options = { remove: :posts }
      end

      def get_allowed_stamp_types
        if @item.forum.forum_type == DiscussionConstants::QUESTION_FORUM_TYPE
          # if forum is of question type, the error may be because stamp_type is not included in the list 'answered, unanswered' (or)
          # 'answered' stamp_type could have been set for a topic with no answers or vice versa.
          DiscussionConstants::FORUM_TO_STAMP_TYPE[@item.forum.forum_type][@item.stamp_type] || DiscussionConstants::QUESTION_STAMPS
        else
          DiscussionConstants::FORUM_TO_STAMP_TYPE[@item.forum.forum_type]
        end
      end

      def sanitize_params
        params[cname][:body_html] = params[cname].delete(:message_html) if params[cname].key?(:message_html)
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
        if create?
          if !load_forum
            return false
          else
            fields = DiscussionConstants::CREATE_TOPIC_FIELDS
          end
        else
          fields = get_fields_from_constant(DiscussionConstants::UPDATE_TOPIC_FIELDS)
        end
        params[cname].permit(*(fields))
        topic = ApiDiscussions::TopicValidation.new(params[cname], @item)
        render_errors topic.errors, topic.error_options unless topic.valid?(action_name.to_sym)
      end

      def scoper
        current_account.topics
      end
  end
end

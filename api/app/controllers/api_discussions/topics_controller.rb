module ApiDiscussions
  class TopicsController < ApiApplicationController
    include DiscussionMonitorConcern
    before_filter :load_forum, only: [:forum_topics]

    def create
      @item.user = api_current_user
      post = @item.posts.build(params[cname].select { |x| DiscussionConstants::CREATE_POST_FIELDS.include?(x) })
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
      @topics = paginate_items(@item.topics)
      render '/api_discussions/topics/topic_list'
    end

    def followed_by
      @topics = paginate_items(current_account.topics.followed_by(params[:user_id]))
      render '/api_discussions/topics/topic_list'
    end

    private

      def load_forum
        load_object current_account.forums
      end

      def check_privilege
        show? ? portal_check : super
      end

      def feature_name
        FeatureConstants::DISCUSSION
      end

      def set_custom_errors(_item = @item)
        if @item.errors[:stamp_type].present?
          allowed = Topic::FORUM_TO_STAMP_TYPE[@item.forum.forum_type]
          allowed_string = allowed.join(',')
          allowed_string += 'nil' if allowed.include?(nil)
          @item.errors[:stamp_type] = BaseError::ERROR_MESSAGES['allowed_stamp_type'] % { list: allowed_string }
        end
        ErrorHelper.rename_error_fields({ forum: :forum_id }, @item)
        @error_options = { remove: :posts }
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

      def portal_check
        access_denied if api_current_user.nil? || api_current_user.customer? || !privilege?(:view_forums)
      end

      def assign_protected
        assign_parent @item, :forum_id, params[cname]
      end

      def validate_params
        fields = get_fields("DiscussionConstants::#{action_name.upcase}_TOPIC_FIELDS")
        params[cname].permit(*(fields))
        topic = ApiDiscussions::TopicValidation.new(params[cname], @item)
        render_errors topic.errors, topic.error_options unless topic.valid?
      end

      def scoper
        current_account.topics
      end
  end
end

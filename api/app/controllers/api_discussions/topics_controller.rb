module ApiDiscussions
  class TopicsController < ApiApplicationController
    include DiscussionMonitorConcern

    def create
      post = @item.posts.build(params[cname].select { |x| DiscussionConstants::CREATE_POST_FIELDS.values.flatten.include?(x) })
      assign_user_and_parent post, :topic, @item
      super
    end

    def update
      post = @item.first_post
      post.attributes = @item.attributes.extract!(:created_at, :updated_at)
      post.body_html = params[cname][:body_html] if params[cname].key?(:body_html)
      super
    end

    def posts
      @posts = paginate_items(load_association)
      render '/api_discussions/posts/post_list'
    end

    def followed_by
      @topics = paginate_items(current_account.topics.followed_by(params[:user_id]))
      render '/api_discussions/topics/topic_list'
    end

    private

      def load_object
        return if is_following? || followed_by?
        super
      end

      def check_privilege
        show? ? portal_check : super
      end

      def before_validation
        can_send_user? 
      end

      def feature_name
        FeatureConstants::DISCUSSION
      end

      def load_association
        @posts = @item.posts
      end

      def set_custom_errors
        @error_options = { remove: :posts }
        ErrorHelper.rename_error_fields({ forum: :forum_id, user: ParamsHelper.get_user_param(@email) }, @item)
      end

      def manipulate_params
        params[cname][:body_html] = params[cname].delete(:message_html) if params[cname].key?(:message_html)
        @email = params[cname].delete(:email) if params[cname].key?(:email)
      end

      def assign_user_and_parent(item, parent, value)
        if @email.present?
          item.user = @user # will be set in can_send_user?
        elsif params[cname][:user_id]
          item.user_id ||= params[cname][:user_id]
        else
          item.user ||= current_user
        end
        if item.has_attribute?(parent.to_sym) # eg: topic has forum_id
          item.send(:write_attribute, parent, value[parent]) if value.key?(parent)
        else
          item.association(parent.to_sym).writer(value) # here topic is not yet saved hence, topic_id cannot be retrieved.
        end
      end

      def portal_check
        access_denied if current_user.nil? || current_user.customer? || !privilege?(:view_forums)
      end

      def assign_protected
        assign_user_and_parent @item, :forum_id, params[cname]
      end

      def validate_params
        fields = get_fields("DiscussionConstants::#{action_name.upcase}_TOPIC_FIELDS")
        params[cname].permit(*(fields))
        topic = ApiDiscussions::TopicValidation.new(params[cname], @item)
        render_error topic.errors, topic.error_options unless topic.valid?
      end

      def scoper
        current_account.topics
      end
  end
end

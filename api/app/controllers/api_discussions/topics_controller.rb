module ApiDiscussions
  class TopicsController < ApiApplicationController
    before_filter { |c| c.requires_feature :forums }
    skip_before_filter :check_privilege, :verify_authenticity_token,
                       only: [:show, :follow, :unfollow, :is_following, :followed_by]
    skip_before_filter :load_object, only: [:followed_by, :create, :index, :is_following]
    include DiscussionMonitorConcern # Order of including concern should not be changed as there are before filters included in this concern
    before_filter :portal_check, only: [:show]
    before_filter :can_send_user?, only: [:create, :follow, :unfollow]
    before_filter :set_forum_id, only: [:create, :update]

    def create
      post = @topic.posts.build(params[cname].symbolize_keys.delete_if { |x| !(ApiConstants::CREATE_POST_FIELDS.values.flatten.include?(x)) })
      assign_user_and_parent post, :topic, @topic
      super
    end

    def update
      post = @topic.first_post
      post.attributes = @topic.attributes.extract!(:created_at, :updated_at)
      post.body_html = params[cname][:body_html] if params[cname].key?(:body_html)
      super
    end

    def posts
      @posts = paginate_items(@topic.posts)
      render template: '/api_discussions/posts/post_list'
    end

    def followed_by
      @topics = paginate_items(current_account.topics.followed_by(params[:user_id]))
      render template: '/api_discussions/topics/topic_list'
    end

    private

    def load_association
      @posts = @topic.posts
    end

    def set_custom_errors
      @error_options = { remove: :posts }
    end

    def manipulate_params
      params[cname][:body_html] = params[cname].delete(:message_html) if params[cname].key?(:message_html)
      @email = params[cname].delete(:email) if params[cname].key?(:email)
    end

    def assign_user_and_parent(item, parent, value)
      if @email.present?
        item.user = @user
      elsif params[cname][:user_id]
        item.user_id ||= params[cname][:user_id]
      else
        item.user ||= current_user
      end
      if item.has_attribute?(parent.to_sym)
        item.send(:write_attribute, parent, value[parent]) if value.key?(parent)
      else
        item.association(parent.to_sym).writer(value)
      end
    end

    def portal_check
      access_denied if current_user.nil? || current_user.customer? || !privilege?(:view_forums)
    end

    def set_forum_id
      assign_user_and_parent @topic, :forum_id, params[cname]
    end

    def validate_params
      fields = get_fields("ApiConstants::#{action_name.upcase}_TOPIC_FIELDS")
      params[cname].permit(*(fields.map(&:to_s)))
      topic = ApiDiscussions::TopicValidation.new(params[cname], @item)
      render_error topic.errors unless topic.valid?
    end

    def scoper
      current_account.topics
    end
  end
end

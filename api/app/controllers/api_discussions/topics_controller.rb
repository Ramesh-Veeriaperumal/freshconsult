module ApiDiscussions
  class TopicsController < ApiApplicationController
    
    before_filter { |c| c.requires_feature :forums }  
    skip_before_filter :check_privilege, :verify_authenticity_token,
     :only => [:show, :follow, :unfollow, :is_following, :followed_by]
    skip_before_filter :load_object, :only => [:followed_by, :create, :index, :is_following]
    include Api::DiscussionMonitorConcern
    before_filter :portal_check, :only => [:show]
    before_filter :can_send_user?, :only => [:create, :follow, :unfollow]
    before_filter :set_forum_id, :only => [:create, :update]
    
    def create
      post = @topic.posts.build(params[cname].symbolize_keys.delete_if{|x| !(ApiConstants::CREATE_POST_FIELDS.values.flatten.include?(x))})
      assign_user_and_parent post, :topic, @topic
      super
    end

    def update
      post = @topic.first_post
      post.attributes = @topic.attributes.extract!(:created_at, :updated_at)
      post.body_html = params[cname][:body_html] if params[cname].has_key?(:body_html)
      super
    end

    def posts
      @posts = paginate_items(@topic.posts)
      render :partial => '/api_discussions/posts/post_list' #Need to revisit this based on eager loading associations in show
    end

  private

    def load_association
      @posts = @topic.posts
    end

    def set_custom_errors
      @error_options = {:remove => :posts}
    end

    def manipulate_params
      params[cname][:body_html] = params[cname].delete(:message_html) if params[cname].has_key?(:message_html)
      @email = params[cname].delete(:email) if params[cname].has_key?(:email)
    end

    def assign_user_and_parent item, parent, value
      if @email.present?
        item.user = @user
      else
        item.user_id ||= (params[cname][:user_id] || current_user.id)
      end
      if item.has_attribute?(parent.to_sym)
        item.send(:write_attribute, parent, value[parent]) if value.has_key?(parent)
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
			unless topic.valid?
				render_error topic.errors
			end
		end

    def scoper
      current_account.topics
    end
  end
end
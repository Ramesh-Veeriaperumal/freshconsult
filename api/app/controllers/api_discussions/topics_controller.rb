module ApiDiscussions
  class TopicsController < ApiApplicationController
    wrap_parameters :topic, :exclude => [] # wp wraps only attr_accessible if this is not specified.
     
    before_filter { |c| c.requires_feature :forums }        
    skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:show]
    before_filter :portal_check, :only => [:show]
    
    def create
      assign_user_and_parent @topic, "forum_id", params[cname][:forum_id]
      @post  = @topic.posts.build(params[cname].symbolize_keys.delete_if{|x| !(ApiConstants::CREATE_POST_FIELDS.values.flatten.include?(x))})
      assign_user_and_parent @post, "topic", @topic
      super
    end

    def update
      msg = params[cname].delete(:message_html) #manipulate_params will be useful?
      assign_other_params # shall we check for the feasibility of using assign_user_and_parent
      @topic.attributes = params[cname]

      @post = @topic.first_post
      @post.attributes = @topic.attributes.extract!(:created_at, :updated_at)
      @post.body_html = msg if params[cname].has_key?(:message_html)
      super
    end

    protected

    def manipulate_params
      params[cname][:body_html] = params[cname].delete(:message_html)
    end

    def assign_other_params
      if params[:email].present? # update should not allow user_id
        @topic.user = current_account.all_users.find_by_email(params[cname][:email])
      else
        @topic.user_id ||= (params[cname][:user_id] || current_user.id)
      end
      @topic.forum_id = params[cname][:forum_id] if params[cname][:forum_id]
      params[cname].extract!(:email, :user_id, :forum_id)
    end

    def assign_user_and_parent item, parent, value
      if params[:email].present?
        item.user = current_account.all_users.find_by_email(params[cname][:email])
      else
        item.user_id ||= (params[cname][:user_id] || current_user.id)
      end
      unless item.has_attribute?(parent.to_sym)
        item.association(parent.to_sym).writer(value) if value
      else
        item.send(:write_attribute, parent, value) if value
      end
    end


		private

		def portal_check
			access_denied if current_user.nil? || current_user.customer? || !privilege?(:view_forums)
		end

		def set_forum_id
			@topic.forum_id = params[cname]["forum_id"] 
		end

		def validate_params
      fields = get_fields("ApiConstants::#{action_name.upcase}_TOPIC_FIELDS")
			(params[cname] || {}).permit(*(fields.map(&:to_s)))
			topic = ApiDiscussions::TopicValidation.new(params[cname], @item)
			unless topic.valid?
				@errors = format_error(topic.errors)
				render :template => '/bad_request_error', :status => 400
			end
		end

    def scoper
      current_account.topics
    end
  end
end
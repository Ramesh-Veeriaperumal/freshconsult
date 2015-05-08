module ApiDiscussions
  class TopicsController < ApiApplicationController
    wrap_parameters :topic, :exclude => [] # wp wraps only attr_accessible if this is not specified.
    include ApiDiscussions::DiscussionsTopic
     
    before_filter { |c| c.requires_feature :forums }        
    skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:show]
    before_filter :portal_check, :only => [:show]
    # before_filter :set_account_and_category_id, :only => [:create]


    def update
      msg = params[cname].delete(:message_html)
      assign_other_params
      @topic.attributes = params[cname]

      @post = @topic.first_post
      @post.attributes = @topic.attributes.extract!(:created_at, :updated_at)
      @post.body_html = msg if params[cname].has_key?(:message_html)
      super
    end

    protected

    def assign_other_params
      if params[:email].present?
        @topic.user = current_account.all_users.find_by_email(params[cname][:email])
      else
        @topic.user_id ||= (params[cname][:user_id] || current_user.id)
      end
      @topic.forum_id = params[cname][:forum_id] if params[cname][:forum_id]
      params[cname].extract!(:email, :user_id, :forum_id)
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
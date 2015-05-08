module ApiDiscussions
  class TopicsController < ApiApplicationController
    wrap_parameters :topic, :exclude => [] # wp wraps only attr_accessible if this is not specified.
    include ApiDiscussions::DiscussionsTopic
     
    before_filter { |c| c.requires_feature :forums }        
    skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:show]
    before_filter :portal_check, :only => [:show]
    # before_filter :set_account_and_category_id, :only => [:create]


    # def update
    #   msg_param = params[cname].extract!(:message_html)
    #   assign_other_params
    #   @topic.attributes = params[cname]

    #   @post = @topic.first_post
    #   @post.attributes = @topic.attributes.extract!(:forum_id, :created_at, :updated_at).merge(msg_param)
    #   @topic.body_html = @post.body_html  
    #   super
    # end

    # def assign_other_params
    #   if params[:email].present?
    #     @topic.user = current_account.all_users.find_by_email(params[cname][:email])
    #   else
    #     @topic.user_id ||= (params[cname][:user_id] || current_user.id)
    #   end
    #   @topic.account_id = current_account.id
    #   @topic.forum_id = params[cname][:forum_id] if params[cname][:forum_id]
    #   params[cname].extract!(:email, :user_id, :forum_id)
    # end

		protected

		private

			def portal_check
				access_denied if current_user.nil? || current_user.customer? || !privilege?(:view_forums)
			end

			def set_forum_id
				@topic.forum_id = params[cname]["forum_id"] 
			end

			def validate_params
               fields = get_fields(action_name)
				params[cname].permit(*(fields.map(&:to_s)))
				topic = ApiDiscussions::TopicValidation.new(params[cname], @item)
				unless topic.valid?
					@errors = format_error(topic.errors)
					render :template => '/bad_request_error', :status => 400
				end
			end

		    def get_fields(action_name)
		      constant = "ApiConstants::#{action_name}_TOPIC_FIELDS".constantize
		      fields = constant.extract!(:all) 
		      constant.keys.each{|key| fields += constant[key] if privilege?(key)}
		      fields
		    end
  end
end
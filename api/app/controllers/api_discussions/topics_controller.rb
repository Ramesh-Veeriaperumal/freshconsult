module ApiDiscussions
  class TopicsController < ApiApplicationController
    wrap_parameters :topic, :exclude => [] # wp wraps only attr_accessible if this is not specified.
    before_filter :validate_params, :only => [:create, :update]
    include ApiDiscussions::DiscussionsTopic
     
    before_filter { |c| c.requires_feature :forums }        
    skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:show]
    before_filter :portal_check, :only => [:show]
    before_filter :set_account_and_category_id, :only => [:create]

		protected

		private

			def portal_check
				access_denied if current_user.nil? || current_user.customer? || !privilege?(:view_forums)
			end

			def set_forum_id
				@topic.forum_id = params[cname]["forum_id"] 
			end

			def validate_params
				params.require(cname).permit(*(ApiConstants::TOPIC_FIELDS.map(&:to_s)))
				topic = ApiDiscussions::TopicValidation.new(params[cname], @item)
				unless topic.valid?
					@errors = format_error(forum.errors)
					render :template => '/bad_request_error', :status => 400
				end
			end
  end
end
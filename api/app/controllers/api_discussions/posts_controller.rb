module ApiDiscussions
  class PostsController < ApiApplicationController
    wrap_parameters :post, :exclude => [] # wp wraps only attr_accessible if this is not specified.
    include ApiDiscussions::DiscussionsPost
     
    before_filter { |c| c.requires_feature :forums }        
    before_filter :set_user_and_topic_id, :only => [:create]

		protected

		private

			def set_user_and_topic_id
				@post.topic_id = params[cname]["topic_id"] 
				@post.user_id ||= current_user.id
				@post.portal = current_portal # is it needed for API?
			end

			def validate_params
				fields = get_fields("ApiConstants::#{action_name.upcase}_POST_FIELDS")
				(params[cname] || {}).permit(*(fields.map(&:to_s)))
				post = ApiDiscussions::PostValidation.new(params[cname], @post)
				unless post.valid?
					@errors = format_error(post.errors)
					render :template => '/bad_request_error', :status => 400
				end
			end
  end
end
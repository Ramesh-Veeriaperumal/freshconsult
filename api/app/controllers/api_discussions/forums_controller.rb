module ApiDiscussions
  class ForumsController < ApiApplicationController
    wrap_parameters :forum, :exclude => [] # wp wraps only attr_accessible if this is not specified.
    before_filter :validate_params, :only => [:create, :update]
    include ApiDiscussions::DiscussionsForum
     
    before_filter { |c| c.requires_feature :forums }        
    skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:show]
    before_filter :portal_check, :only => [:show]
    before_filter :set_account_and_category_id, :only => [:create]

		protected

		private

			def portal_check
				access_denied if current_user.nil? || current_user.customer? || !privilege?(:view_forums)
			end

			def set_account_and_category_id # why assign account_id?
				@forum.account_id ||= current_account.id
				@forum.forum_category_id = params[cname]["forum_category_id"]
			end

			def validate_params
				params.require(cname).permit(*(ApiConstants::FORUM_FIELDS.map(&:to_s)))
				forum = ApiDiscussions::ForumValidation.new(params[cname], @item)
				unless forum.valid?
					@errors = format_error(forum.errors)
					render :template => '/bad_request_error', :status => 400
				end
			end
  end
end
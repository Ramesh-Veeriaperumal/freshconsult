module ApiDiscussions
  class ForumsController < ApiApplicationController
    include Discussions::ForumConcern
     
    before_filter { |c| c.requires_feature :forums }        
    skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:show]
    before_filter :portal_check, :only => [:show]
    before_filter :set_account_and_category_id, :only => [:create]

		protected

		private

      def set_custom_errors
        bad_customer_ids = @item.customer_forums.select{|x| x.errors.present?}.collect(&:customer_id).map(&:to_s)
        @item.errors.add("customers", "list is invalid") if bad_customer_ids.present?
        @error_options = {:remove => :customer_forums, :meta => "#{bad_customer_ids.join(', ')}"}
      end

      def manipulate_params
        set_customer_forum_params
      end

			def portal_check
				access_denied if current_user.nil? || current_user.customer? || !privilege?(:view_forums)
			end

			def set_account_and_category_id # why assign account_id?
				@forum.account_id ||= current_account.id
				@forum.forum_category_id = params[cname]["forum_category_id"] # shall we use this assign_forum_category_id method
			end

			def validate_params
				params[cname].permit(*(ApiConstants::FORUM_FIELDS.map(&:to_s)))
				forum = ApiDiscussions::ForumValidation.new(params[cname], @item)
				unless forum.valid?
					@errors = format_error(forum.errors)
					render :template => '/bad_request_error', :status => 400
				end
			end
  end
end
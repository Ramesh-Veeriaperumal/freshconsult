module ApiDiscussions::Pipe
  class ApiCommentsController < ApiDiscussions::ApiCommentsController
    private

    def build_object
        # assign already loaded account object so that it will not be queried repeatedly in model
      	account_included = scoper.attribute_names.include?('account_id')
      	build_params = account_included ? { account: current_account } : {}
      	@item = scoper.new(build_params.merge(params[cname]))

      	# assign account separately if it is protected_attribute.
      	@item.account = current_account if account_included
        @item.user_id = params[cname][:user_id]
        @item.portal = current_portal
        @item.topic = @topic
     end

      def validate_params
        return false if create? && !load_topic
        params[cname].permit(*get_fields("DiscussionConstants::PIPE_CREATE_COMMENT_FIELDS"))
        comment = ApiDiscussions::Pipe::ApiCommentValidation.new(params[cname], @item)
        render_errors comment.errors, comment.error_options unless comment.valid?(action_name.to_sym)
      end
  end
end

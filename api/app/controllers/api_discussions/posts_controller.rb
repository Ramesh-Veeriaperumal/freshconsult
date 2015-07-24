module ApiDiscussions
  class PostsController < ApiApplicationController
    def create
      if @email.present?
        @item.user = @user
      elsif params[cname][:user_id]
        @item.user_id ||= params[cname][:user_id]
      else
        @item.user = current_user
      end
      super
    end

    private

      def before_validation
        can_send_user?
      end

      def build_object
        super
        set_user_and_topic_id
        check_lock
      end

      def feature_name
        FeatureConstants::DISCUSSION
      end

      def set_custom_errors(_item = @item)
        ErrorHelper.rename_error_fields({ topic: :topic_id, user: ParamsHelper.get_user_param(@email) }, @item)
      end

      def manipulate_params
        @email = params[cname].delete(:email) if params[cname][:email]
      end

      def set_user_and_topic_id
        @item.topic_id = params[cname]['topic_id']
        @item.user_id ||= current_user.id
        @item.portal = current_portal
      end

      def validate_params
        fields = get_fields("DiscussionConstants::#{action_name.upcase}_POST_FIELDS")
        params[cname].permit(*(fields))
        post = ApiDiscussions::PostValidation.new(params[cname], @item)
        render_error post.errors, post.error_options unless post.valid?
      end

      def scoper
        current_account.posts
      end

      def check_lock
        if params[cname][:user_id] || params[cname][:email] # email is removed from params, as it is not a model attr.
          locked = @item.topic.try(:locked?)
          if locked # if topic is locked, a customer cannot post.
            customer = @user.try(:is_customer)
            render_request_error(:access_denied, 403, id: @user.id, name: @user.name) if customer
          end
        end
      end
  end
end

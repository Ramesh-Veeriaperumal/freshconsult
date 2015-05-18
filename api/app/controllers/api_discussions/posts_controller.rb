module ApiDiscussions
  class PostsController < ApiApplicationController
    before_filter { |c| c.requires_feature :forums }
    before_filter :set_user_and_topic_id, only: [:create]
    before_filter :can_send_user?, :check_lock, only: :create

    def create
      if @email.present?
        @post.user = @user
      else
        @post.user_id ||= (params[cname][:user_id] || current_user.id)
      end
      super
    end

    private

    def manipulate_params
      @email = params[cname].delete(:email) if params[cname][:email]
    end

    def set_user_and_topic_id
      @post.topic_id = params[cname]['topic_id']
      @post.user_id ||= current_user.id
      @post.portal = current_portal
    end

    def validate_params
      fields = get_fields("ApiConstants::#{action_name.upcase}_POST_FIELDS")
      params[cname].permit(*(fields.map(&:to_s)))
      post = ApiDiscussions::PostValidation.new(params[cname], @post)
      render_error post.errors unless post.valid?
    end

    def scoper
      current_account.posts
    end

    def check_lock
      if params[cname][:user_id] || @email # email is removed from params, as it is not a model attr.
        locked = @post.topic.try(:locked?)
        if locked
          customer = @user.try(:is_customer)
          render_invalid_user_error if customer
        end
      end
    end
  end
end

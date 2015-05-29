module ApiDiscussions
  class ForumsController < ApiApplicationController
    include Discussions::ForumConcern

    before_filter { |c| c.requires_feature :forums }
    skip_before_filter :check_privilege, :verify_authenticity_token, only: [:follow, :unfollow, :is_following]
    skip_before_filter :load_object, only: [:create, :is_following]
    include Api::DiscussionMonitorConcern
    before_filter :set_account_and_category_id, only: [:create]
    before_filter :can_send_user?, only: [:follow, :unfollow]

    def topics
      @topics = paginate_items(@forum.topics)
      render template: '/api_discussions/topics/topic_list'
    end

    private

    def load_association
      @topics = @forum.topics
    end

    def set_custom_errors
      bad_customer_ids = @item.customer_forums.select { |x| x.errors.present? }.collect(&:customer_id).map(&:to_s)
      @item.errors.add('customers', 'list is invalid') if bad_customer_ids.present?
      @error_options = { remove: :customer_forums, meta: "#{bad_customer_ids.join(', ')}" }
    end

    def manipulate_params
      set_customer_forum_params
    end

    def portal_check
      access_denied if current_user.nil? || current_user.customer? || !privilege?(:view_forums)
    end

    def set_account_and_category_id
      @forum.account_id ||= current_account.id
      @forum.forum_category_id = params[cname]['forum_category_id'] # shall we use this assign_forum_category_id method
    end

    def validate_params
      fields = ApiConstants::API_FORUM_FIELDS[params[cname][:forum_visibility].to_i] || ApiConstants::FORUM_FIELDS
      params[cname].permit(*(fields.map(&:to_s)))
      forum = ApiDiscussions::ForumValidation.new(params[cname], @item)
      render_error forum.errors unless forum.valid?
    end
  end
end

module ApiDiscussions
  class ForumsController < ApiApplicationController
    before_filter { |c| c.requires_feature :forums }
    skip_before_filter :load_object, only: [:create, :is_following]
    include DiscussionMonitorConcern
    before_filter :set_account_and_category_id, only: [:create, :update]
    before_filter :can_send_user?, only: [:follow, :unfollow]

    def topics
      @topics = paginate_items(load_association)
      render '/api_discussions/topics/topic_list'
    end

    def destroy
      # Needed for removing es index for topic. Shouldn't be part of topic model. Performance constraints to enqueue jobs for each topic
      @forum.backup_forum_topic_ids
      super
    end

    private

      def scoper
        current_account.forums
      end

      def load_association
        @topics = @forum.topics
      end

      def manipulate_params
        customers = params[cname]['customers'] || []
        params[cname][:customer_forums_attributes] = { customer_id: customers }
      end

      def set_account_and_category_id
        @forum.account_id ||= current_account.id
        @forum.forum_category_id = params[cname]['forum_category_id'] if params[cname]['forum_category_id']
      end

      def validate_params
        params[cname].permit(*(DiscussionConstants::FORUM_FIELDS))
        forum_val = ApiDiscussions::ForumValidation.new(params[cname], @forum)
        render_error forum_val.errors, forum_val.error_options unless forum_val.valid?
      end

      def set_custom_errors
        bad_customer_ids = @forum.customer_forums.select { |x| x.errors.present? }.collect(&:customer_id)
        @forum.errors.add('customers', 'list is invalid') if bad_customer_ids.present?
        @error_options = { remove: :customer_forums, customers: { list: "#{bad_customer_ids.join(', ')}" } }
        ErrorHelper.rename_error_fields({ forum_category: :forum_category_id }, @forum)
      end
  end
end

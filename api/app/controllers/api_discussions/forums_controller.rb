module ApiDiscussions
  class ForumsController < ApiApplicationController
    include DiscussionMonitorConcern

    def topics
      @topics = paginate_items(load_association)
      render '/api_discussions/topics/topic_list'
    end

    def destroy
      # Needed for removing es index for topic. Shouldn't be part of topic model. Performance constraints to enqueue jobs for each topic
      @item.backup_forum_topic_ids
      super
    end

    private

      def load_object
        return if is_following?
        super
      end

      def feature_name
        FeatureConstants::DISCUSSION
      end

      def scoper
        current_account.forums
      end

      def load_association
        @topics = @item.topics
      end

      def manipulate_params
        customers = params[cname]['customers'] || []
        params[cname][:customer_forums_attributes] = { customer_id: customers }
      end

      def assign_protected
        @item.account_id ||= current_account.id
        @item.forum_category_id = params[cname]['forum_category_id'] if params[cname]['forum_category_id']
      end

      def validate_params
        params[cname].permit(*(DiscussionConstants::FORUM_FIELDS))
        forum_val = ApiDiscussions::ForumValidation.new(params[cname], @item)
        render_error forum_val.errors, forum_val.error_options unless forum_val.valid?
      end

      def set_custom_errors
        bad_customer_ids = @item.customer_forums.select { |x| x.errors.present? }.collect(&:customer_id)
        @item.errors.add('customers', 'list is invalid') if bad_customer_ids.present?
        @error_options = { remove: :customer_forums, customers: { list: "#{bad_customer_ids.join(', ')}" } }
        ErrorHelper.rename_error_fields({ forum_category: :forum_category_id }, @item)
      end
  end
end

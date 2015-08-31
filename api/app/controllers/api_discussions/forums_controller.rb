module ApiDiscussions
  class ForumsController < ApiApplicationController
    include DiscussionMonitorConcern
    before_filter :load_category, only: [:category_forums]

    def destroy
      # Needed for removing es index for topic. Shouldn't be part of topic model. Performance constraints to enqueue jobs for each topic
      @item.backup_forum_topic_ids
      super
    end

    def category_forums
      paginate_items(@item.forums, 'forums')
      render '/api_discussions/forums/forum_list' # Need to revisit this based on eager loading associations in show
    end

    private

      def load_category
        load_object current_account.forum_categories
      end

      def feature_name
        FeatureConstants::DISCUSSION
      end

      def scoper
        current_account.forums
      end

      def sanitize_params
        prepare_array_fields ['company_ids']
        customers = params[cname]['company_ids']
        params[cname][:customer_forums_attributes] = { customer_id: customers } unless params[cname]['company_ids'].nil?
      end

      def assign_protected
        @item.account_id ||= current_account.id
        @item.forum_category_id = params[cname]['forum_category_id'] if params[cname]['forum_category_id']
      end

      def validate_params
        params[cname].permit(*(DiscussionConstants::FORUM_FIELDS))
        forum_val = ApiDiscussions::ForumValidation.new(params[cname], @item)
        render_errors forum_val.errors, forum_val.error_options unless forum_val.valid?
      end

      def set_custom_errors(_item = @item)
        bad_customer_ids = @item.customer_forums.select { |x| x.errors.present? }.collect(&:customer_id)
        @item.errors.add('company_ids', 'list is invalid') if bad_customer_ids.present?
        @error_options = { remove: :customer_forums, company_ids: { list: "#{bad_customer_ids.join(', ')}" } }
        ErrorHelper.rename_error_fields({ forum_category: :forum_category_id }, @item)
        @error_options
      end
  end
end

module Ember::Dashboard
  class ActivitiesController < ApiApplicationController
    include HelperConcern
    around_filter :run_on_slave

    decorate_views(decorate_objects: [:index])

    def index
      since_id = params[:since_id]
      if since_id.blank?
        load_items
        response.api_root_key = :recent_activities
      else
        @items = Helpdesk::Activity.freshest(current_account).only_tickets.activity_since(since_id).permissible(current_user).includes(:notable, user: :avatar).limit(DashboardConstants::DEFAULT_PAGE_LIMIT)
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e, description: 'Error occoured in dashboard activities')
      render_base_error(:internal_error, 500)
    end

    def per_page
      per_page_params = (params[:per_page] || DashboardConstants::DEFAULT_PAGE_LIMIT).to_i
      items_per_page = if per_page_params > DashboardConstants::MAX_PAGE_LIMIT
                         DashboardConstants::MAX_PAGE_LIMIT
                       elsif per_page_params < DashboardConstants::MIN_PAGE_LIMIT
                         DashboardConstants::MIN_PAGE_LIMIT
                       else
                         per_page_params
                       end
      items_per_page
    end

    private

      def load_items
        recent_activities = recent_activities(params[:before_id])
        @items = paginate_items(recent_activities)
      end

      def validate_filter_params
        @validation_klass = 'DashboardValidation'
        validate_query_params
      end

      def constants_class
        :DashboardConstants.to_s.freeze
      end

    protected

      def recent_activities(before_id)
        if before_id.to_i > 0
          Helpdesk::Activity.freshest(current_account).only_tickets.activity_before(before_id).permissible(current_user).includes(:notable, user: :avatar)
        else
          Helpdesk::Activity.freshest(current_account).only_tickets.permissible(current_user).includes(:notable, user: :avatar)
        end
      end
  end
end

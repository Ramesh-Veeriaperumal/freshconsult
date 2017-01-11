module Ember
  class TicketFiltersController < ApiApplicationController
    include AccessibleControllerMethods

    before_filter :has_permission?, only: [:update, :destroy]

    def index
      load_objects
      append_default_filters
      transform_response(@items)
    end

    def show
      @item = transform_single_response(required_attributes(@item))
    end

    def create
      @item.validate!
      if @item.errors?
        render_errors(@item.errors, meta = {}) and return
      else  
        @item.save
        create_helpdesk_accessible(@item, :ticket_filter)
      end
      @item = transform_single_response(required_attributes(@item))
    end

    def update
      set_model_query_hash
      prefix_ff_params
      @item.deserialize_from_params(hasherized_params)
      @item.visibility = params[:ticket_filter][:visibility]
      if @item.save
        update_helpdesk_accessible(@item, :ticket_filter) if visibility_present?
      else
        render_errors(@item.errors, meta = {}) and return
      end
      @item = transform_single_response(required_attributes(@item))
    end

    def destroy
      @item.destroy
      head 204
    end

    private

      def validate_params
        params[cname].permit(*CustomFilterConstants::INDEX_FIELDS)
        @custom_ticket_filter = CustomTicketFilterValidation.new(params[cname])
        render_errors(@custom_ticket_filter.errors, @custom_ticket_filter.error_options) unless @custom_ticket_filter.valid?
      end

      def load_objects
        @items = scoper.my_ticket_filters(api_current_user).collect do |filter|
          required_attributes(filter)
        end
      end

      def load_object
        # Check whether the filter is accessible to the user
        if is_num?(params[:id])
          @item = scoper.find_by_id(params[:id])
        else
          @item = (default_visible_filters | default_hidden_filters).select { |filter| filter[:id] == params[:id] }.first
        end
        log_and_render_404 unless @item
      end

      def scoper
        current_account.ticket_filters
      end

      def before_build_object
        default_visibility
        set_model_query_hash
      end

      def build_object
        prefix_ff_params
        @item = Helpdesk::Filters::CustomTicketFilter.deserialize_from_params(hasherized_params)
        @item.visibility = params[:ticket_filter][:visibility]
        @item.account_id = current_account.id
      end

      def required_attributes(obj)
        obj.is_a?(Helpdesk::Filters::CustomTicketFilter) ? obj.attributes.slice('id', 'name').merge(extra_filter_params(obj)) : obj
      end

      def extra_filter_params(obj)
        { 
          default: false, 
          order: obj.data[:wf_order],
          order_type: obj.data[:wf_order_type],
          per_page: obj.data[:wf_per_page],
          query_hash: obj.data[:data_hash]
        }
      end

      def append_default_filters
        @items |= default_visible_filters | default_hidden_filters
      end

      def default_visible_filters
        TicketsFilter.default_views.collect do |filter|
          if filter[:id].eql?('raised_by_me')
            filter.merge(query_hash: Helpdesk::Filters::CustomTicketFilter.new.raised_by_me_filter)
          # We shouldn't show the query hash for these default filters
          elsif CustomFilterConstants::REMOVE_QUERY_HASH.include?(filter[:id])
            filter
          else
            filter.merge(query_hash: Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS[filter[:id]])
          end
        end
      end

      def default_hidden_filters
        hidden_filter_names.collect do |filter|
          {
            id: filter, 
            name: I18n.t("helpdesk.tickets.views.#{filter}"), 
            default: true,
            hidden: true,
            query_hash: filter.eql?('on_hold') ? Helpdesk::Filters::CustomTicketFilter.new.on_hold_filter : Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS[filter]
          }
        end
      end

      def hidden_filter_names
        TicketFilterConstants::HIDDEN_FILTERS - (current_account.sla_management_enabled? ? [] : ['overdue', 'due_today'])
      end

      def has_permission?
        unless @item.is_a?(Helpdesk::Filters::CustomTicketFilter) && @item.accessible.user_id == api_current_user.id
          render_request_error :access_denied, 403
        end
      end

      def is_num?(str)
        Integer(str.to_s)
        rescue ArgumentError
          false
        else
          true
      end

      def transform_response(items)
        items.map { |item| transform_single_response(item) }
      end

      def transform_single_response(item)
        return item unless item[:query_hash]
        # remove the spam & deleted conditions from query hash
        item[:query_hash] = remove_query_conditions(item)
        # transform query hash to a presentable form
        item[:query_hash] = QueryHash.new(item[:query_hash]).to_json
        item
      end

      def remove_query_conditions(item)
        # This is to be done in QueryHash
        item[:query_hash].select { |query| 
          !CustomFilterConstants::REMOVE_QUERY_CONDITIONS.include?(query['condition'])
        }
      end

      def default_visibility
        params[:ticket_filter][:visibility][:user_id] = api_current_user.id
        unless privilege?(:manage_users)
          params[:ticket_filter][:visibility][:visibility] = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
          params[:ticket_filter][:visibility][:group_id] = nil
        end
        params[:ticket_filter][:visibility][:visibility] ||= Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me] if params[:ticket_filter][:visibility].present?
      end

      def set_model_query_hash
        params[:ticket_filter][:wf_model] = 'Helpdesk::Ticket'
        params[:ticket_filter][:data_hash] = QueryHash.new(params[:ticket_filter][:query_hash]).to_system_format
      end

      def visibility_present?
        params[:ticket_filter][:visibility].present? && params[:ticket_filter][:visibility][:visibility].present?
      end

      def prefix_ff_params
        CustomFilterConstants::WF_PREFIX.each do |key|
          params[:ticket_filter]["wf_#{key}".to_sym] = params[:ticket_filter].delete(key) if params[:ticket_filter][key].present?
        end
        params[:ticket_filter][:filter_name] = params[:ticket_filter][:name] if params[:ticket_filter][:name].present?
      end

      def hasherized_params
        new_params = params[:ticket_filter].to_h.with_indifferent_access.slice(:wf_model, :filter_name, :wf_order, :wf_order_type, :wf_per_page, :data_hash, :visibility)
        new_params[:data_hash].map!(&:to_h).map(&:with_indifferent_access)
        new_params
      end

      wrap_parameters(*Helpdesk::Filters::CustomTicketFilter::EMBER_WRAP_PARAMS)
  end
end

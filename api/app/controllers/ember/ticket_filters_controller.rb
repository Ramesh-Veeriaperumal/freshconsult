module Ember
  class TicketFiltersController < ApiApplicationController
    include AccessibleControllerMethods

    FEATURE_NAME = :custom_ticket_views

    before_filter :has_permission?, only: [:update, :destroy]
    before_filter :check_feature, only: [:update, :destroy, :create]

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
        render_errors(@item.errors, meta = {}) && return
      else
        @item.save
        create_helpdesk_accessible(@item, :ticket_filter)
      end
      @item = transform_single_response(required_attributes(@item))
    end

    def update
      set_model_query_hash
      prefix_ff_params
      set_user_visibility

      @item.deserialize_from_params(hasherized_params)
      @item.visibility = params[:ticket_filter][:visibility]

      if @item.save
        update_helpdesk_accessible(@item, :ticket_filter) if visibility_present?
      else
        render_errors(@item.errors, meta = {}) && return
      end
      @item = transform_single_response(required_attributes(@item))
    end

    def destroy
      @item.destroy
      head 204
    end

    def self.wrap_params
      TicketFilterConstants::WRAP_PARAMS
    end

    private

      def check_feature
        return true if current_account.has_feature?(FEATURE_NAME)
        render_request_error(:require_feature, 403, feature: FEATURE_NAME.to_s.titleize)
      end

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
          @item = nil unless @item.try(:has_permission?, api_current_user)
        else
          @item = (TicketsFilter.default_visible_filters(params[:id]).presence || TicketsFilter.default_hidden_filters(params[:id])).first
        end
        log_and_render_404 if @item.nil?
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
          order_by: obj.data[:wf_order],
          order_type: obj.data[:wf_order_type],
          per_page: obj.data[:wf_per_page],
          query_hash: obj.data[:data_hash],
          visibility: visibility_attributes(obj),
          created_at: obj[:created_at].try(:utc),
          updated_at: obj[:updated_at].try(:utc)
        }
      end

      def visibility_attributes(obj)
        (obj.try(:accessible).try(:attributes) || {}).slice(*TicketFilterConstants::VISIBILITY_ATTRIBUTES_NEEDED)
      end

      def append_default_filters
        @items |= TicketsFilter.default_visible_filters | TicketsFilter.default_hidden_filters
      end

      def has_permission?
        # privilege for custom dashboard and ticket filters
        unless @item.is_a?(Helpdesk::Filters::CustomTicketFilter) &&
            (privilege?(:manage_ticket_list_views) || @item.accessible.user_id == api_current_user.id)
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
        item[:query_hash] = QueryHash.new(item[:query_hash], ff_entries: ff_entries).to_json
        item
      end

      def remove_query_conditions(item)
        # This is to be done in QueryHash
        item[:query_hash].select do |query|
          !CustomFilterConstants::REMOVE_QUERY_CONDITIONS.include?(query['condition'])
        end
      end

      def default_visibility
        params[:ticket_filter][:visibility][:user_id] = api_current_user.id
        unless privilege?(:manage_ticket_list_views)
          params[:ticket_filter][:visibility][:visibility] = ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
          params[:ticket_filter][:visibility][:group_id] = nil
        end
        params[:ticket_filter][:visibility][:visibility] ||= ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me] if params[:ticket_filter][:visibility].present?
      end

      def set_model_query_hash
        params[:ticket_filter][:wf_model] = 'Helpdesk::Ticket'
        params[:ticket_filter][:data_hash] = QueryHash.new(params[:ticket_filter][:query_hash], ff_entries: ff_entries).to_system_format
      end

      def visibility_present?
        params[:ticket_filter][:visibility].present? && params[:ticket_filter][:visibility][:visibility].present?
      end

      def prefix_ff_params
        CustomFilterConstants::WF_PREFIX_PARAM_MAPPING.each_pair do |key, val|
          params[:ticket_filter]["wf_#{key}".to_sym] = params[:ticket_filter].delete(val) if params[:ticket_filter][val].present?
        end
        params[:ticket_filter][:filter_name] = params[:ticket_filter][:name] if params[:ticket_filter][:name].present?
      end

      def hasherized_params
        new_params = params[:ticket_filter].to_h.with_indifferent_access.slice(:wf_model, :filter_name, :wf_order, :wf_order_type, :wf_per_page, :data_hash, :visibility)
        new_params[:data_hash].map!(&:to_h).map(&:with_indifferent_access)
        new_params
      end

      def ff_entries
        @ff_entries_cache ||= Account.current.flexifield_def_entries.select('flexifield_alias, flexifield_name').to_a.map(&:attributes)
      end

      def set_user_visibility
        if visibility_present?
          params[:ticket_filter][:visibility][:user_id] = api_current_user.id
        end
      end

      wrap_parameters(*wrap_params)
  end
end

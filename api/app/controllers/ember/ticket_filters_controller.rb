module Ember
  class TicketFiltersController < ApiApplicationController

    REMOVE_QUERY_HASH = ['spam', 'deleted', 'monitored_by']
    REMOVE_QUERY_CONDITIONS = ['spam', 'deleted']

    def index
      load_objects
      append_default_filters
      transform_response
    end

    def show
      @item = transform_each(required_attributes(@item))
    end

    private

      def load_objects
        @items = scoper.my_ticket_filters(api_current_user).collect do |filter|
          required_attributes(filter)
        end
      end

      def load_object
        if is_num?(params[:id])
          @item = scoper.find_by_id(params[:id])
        else
          @item = default_filters.select { |filter| filter[:id] == params[:id] }.first
        end
        log_and_render_404 unless @item
      end

      def after_load_object
        has_permission?
      end

      def scoper
        current_account.ticket_filters
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
        @items |= default_filters
      end

      def default_filters
        TicketsFilter.default_views.collect do |filter|
          if filter[:id].eql?('raised_by_me')
            filter.merge(query_hash: Helpdesk::Filters::CustomTicketFilter.new.raised_by_me_filter)
          # We shouldn't show the query hash for these default filters
          elsif REMOVE_QUERY_HASH.include?(filter[:id])
            filter
          else
            filter.merge(query_hash: Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS[filter[:id]])
          end
        end
      end

      def has_permission?
        if @item.is_a?(Helpdesk::Filters::CustomTicketFilter) && @item.accessible.user_id != api_current_user.id
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

      def transform_response
        @items = @items.map { |item| transform_each(item) }
      end

      def transform_each(item = @item)
        return item unless item[:query_hash]
        # remove the spam & deleted conditions from query hash
        item[:query_hash] = item[:query_hash].select { |query| 
          !REMOVE_QUERY_CONDITIONS.include?(query['condition'])
        }
        # transform query hash to a presentable form
        item[:query_hash] = item[:query_hash].map { |query| query_output(query) }
        item
      end

      def query_output(query)
        result = query.slice('condition', 'operator', 'value')
        result['value'] = query['value'].split(',') if query['value'].is_a?(String)
        result['condition'] = TicketDecorator.display_name(query['ff_name']) if is_flexi_field?(query)
        result['type'] = is_flexi_field?(query) ? 'custom_field' : 'default'
        result
      end

      def is_flexi_field?(query)
        query['ff_name'] != 'default' && query['condition'].include?('flexifield')
      end

      def query_input_transform(query_hash)
        query_hash.map do |query|
          result = query.slice('condition', 'operator', 'value')
          result['value'] = query['value'].join(',') if query['value'].is_a?(Array)
          result['ff_name'] = 'default'

          if query['type'] == 'custom_field'
            ff_name = "#{query['condition']}_#{current_account.id}"
            result['condition'] = "flexifields.#{ff_field_name(ff_name)}"
            result['ff_name'] = ff_name
          end
          result
        end
      end

      def ff_field_name(name)
        current_account.flexifield_def_entries.find_by_flexifield_alias(name).flexifield_name
      end
  end
end

module Ember
  module Segments
    class BaseFiltersController < ApiApplicationController
      decorate_views

      before_filter :access_denied, unless: :require_feature
      before_filter :load_object,   only: [:update, :destroy]
      before_filter :check_filter_count, only: :create

      VIEW_PATH = 'ember/segments/base_filters/%{action}'.freeze
      MAX_SEGMENT_LIMIT = 20

      def index
        @items = scoper
        render(format(VIEW_PATH, action: 'index'))
      end

      def create
        @item = scoper.new(name: params[current_filter][:name], data: params[current_filter][:query_hash])
        render_errors(@item.errors, {}) && return unless @item.save
        render(format(VIEW_PATH, action: 'show'))
      end

      def update
        @item.update_attributes(name: params[current_filter][:name], data: params[current_filter][:query_hash])
        render_errors(@item.errors, {}) && return if @item.errors.present?
        render(format(VIEW_PATH, action: 'show'))
      end

      def self.decorator_name
        ::Segments::FilterDecorator
      end

      private

        def load_object
          @item = scoper.find_by_id(params[:id].to_i)
          head 404 if @item.nil?
        end

        def require_feature
          current_account.segments_enabled?
        end

        def check_filter_count
          render_errors({ current_usage: current_filter_count.to_s }, {}) if limit_exceeded?
        end

        def limit_exceeded?
          (current_filter_count >= MAX_SEGMENT_LIMIT) && (current_filter_count >= max_limit)
        end

        def max_limit
          get_others_redis_key(segment_limit_key).to_i
        end

        def segment_limit_key
          format(SEGMENT_LIMIT, account_id: current_account.id)
        end

        def current_filter_count
          @current_filter_count ||= (current_account.contact_filters.count + current_account.company_filters.count)
        end
    end
  end
end

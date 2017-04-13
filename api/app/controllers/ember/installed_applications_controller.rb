module Ember
  class InstalledApplicationsController < ApiApplicationController
    include HelperConcern

    decorate_views

    private

      def scoper
        current_account.installed_applications.includes(:application)
      end

      def load_objects(items = scoper)
        @items = params[:name] ? scoper.where(*filter_conditions) : items
      end

      def filter_conditions
        app_names = params[:name].split(',')
        ['applications.name in (?)', app_names]
      end

      def validate_filter_params
        @constants_klass = 'InstalledApplicationConstants'
        @validation_klass = 'InstalledApplicationValidation'
        validate_query_params
      end

      def load_object
        @item = scoper.detect { |installed_applications| installed_applications.id == params[:id].to_i }
        log_and_render_404 unless @item
      end
  end
end

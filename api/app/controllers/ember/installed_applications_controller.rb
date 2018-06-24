module Ember
  class InstalledApplicationsController < ApiApplicationController
    include HelperConcern
    include InstalledApplicationConstants

    decorate_views

    before_filter :load_service_object, only: [:fetch]

    def fetch
      return unless validate_body_params(@item)
      service_object = @service_class.new(@item, params[:payload])
      @data = service_object.receive(params[:event])
      render :fetch, status: service_object.web_meta[:status]
    rescue TimeoutError => error
      render_base_error(:integration_timeout, 503)
    end

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
        validate_query_params
      end

      def constants_class
        INSTALLED_APPLICATION_CONSTANTS
      end

      def load_object
        @item = scoper.detect { |installed_applications| installed_applications.id == params[:id].to_i }
        log_and_render_404 unless @item
      end

      def load_service_object
        service_name = APP_NAME_TO_SERVICE_MAP[@item.application.name.to_sym]
        return render_request_error(:invalid_action, 403) unless service_name
        @service_class = ::IntegrationServices::
                            Service.get_service_class(service_name)
        render_base_error(:integration_service_not_found, 405) unless @service_class
      end
  end
end

module Ember
  class InstalledApplicationsController < ApiApplicationController
    include HelperConcern
    include InstalledApplicationConstants
    include IntegrationServices::Errors
    include Integrations::CloudElements::Crm::CrmUtil

    decorate_views

    before_filter :load_service_object, only: [:fetch, :create]
    before_filter -> { validate_delegator(nil, cname_params) }, only: [:create]

    def fetch
      return unless validate_body_params(@item)
      payload, metadata = construct_app_payload(params[:payload])
      service_object = @service_class.new(@item, payload, metadata)
      response = service_object.receive(params[:event])
      @data = add_additional_property(response, payload)
      render :fetch, status: service_object.web_meta[:status]
    rescue AccessDeniedError => error
      render_request_error(:access_denied, 403)
    rescue TimeoutError => error
      render_base_error(:integration_timeout, 504)
    rescue StandardError => error
      Rails.logger.error "Exception occured :: #{error.message}, trace: #{error.backtrace[0..10]}"
      render_base_error(:bad_gateway, 502)
    end

    def create
      return unless validate_body_params

      config_params = @service_class.construct_default_integration_params(cname_params[:configs])
      @item = Integrations::Application.install_or_update(cname_params[:name], current_account.id, config_params)
      @item ? render(action: :show) : render_custom_errors
    end

    private

      def scoper
        current_account.installed_applications.includes(:application)
      end

      def load_objects(items = scoper)
        @items = params[:name] ? scoper.where(*filter_conditions) : items
      end

      def feature_name
        MARKETPLACE if action == :create
      end

      def filter_conditions
        app_names = params[:name].split(',')
        ['applications.name in (?)', app_names]
      end

      def validate_filter_params
        validate_query_params
      end

      def validate_params
        validate_body_params
      end

      def constants_class
        INSTALLED_APPLICATION_CONSTANTS
      end

      def load_object
        @item = scoper.detect { |installed_applications| installed_applications.id == params[:id].to_i }
        log_and_render_404 unless @item
      end

      def element
        @item.application.name
      end

      def app
        Integrations::Application.find_by_name(element)
      end

      def metadata
        { :app_name => element,
          :element_token => @item.configs_element_token,
          :object => get_crm_constants['objects'][params[:payload][:type]]
        }
      end

      def service_obj(payload, metadata)
        IntegrationServices::Services::CloudElementsService.new(@installed_app, payload, metadata)
      end

      def construct_app_payload(payload)
        if element == "salesforce_v2"
          payload = construct_payload_with_query(payload) if payload[:type] == "account"
          return payload, metadata
        else
          return payload, {}
        end
      end

      def construct_payload_with_query(payload)
        new_metadata = {:app_name => metadata[:app_name],
                    :element_token => metadata[:element_token],
                    :object => get_crm_constants["objects"]["contact"]}
        response = get_contact_account_ids payload[:value][:email], new_metadata
        accIds = Array.new
        response["records"].each do |res|
         accIds.push(res["accountId"])  if res["accountId"].present?
        end
        query = accIds.collect{|id| "#{get_crm_constants['account_name_format']}='#{id}'"}.join(" OR ")
        payload[:value][:query] = query
        payload
      end

      def add_additional_property(response, payload)
        if (element == "salesforce_v2" && payload[:type] == "contact" &&
              @item.configs_contact_fields.include?("AccountName"))
          metadata[:account_object] = get_crm_constants['objects']['account']
          response = get_contact_account_name response, metadata
        end
        response
      end

      def get_contact_account_ids(email, metadata)
        payload = {:email => email}
        service_obj(payload, metadata).receive("get_contact_account_id")
      end

      def load_service_object
        service = action == :create ? cname_params[:name].to_sym : @item.application.name.to_sym
        service_name = APP_NAME_TO_SERVICE_MAP[service]
        return render_request_error(:invalid_action, 403) unless service_name
        @service_class = ::IntegrationServices::
                            Service.get_service_class(service_name)
        render_base_error(:integration_service_not_found, 405) unless @service_class
      end
  end
end

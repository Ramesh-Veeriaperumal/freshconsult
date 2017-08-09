module Ember
  class CustomerImportsController < ApiApplicationController
    include ImportCsvUtil
    include CustomerImportConstants
    include HelperConcern

    def index
      head import_exists?(params[:type]) ? 204 : 404
    end

    def create
      return render_request_error(:existing_import_inprogress, 409) if import_exists?(params[:type]) 
      store_file
      current_account.send(:"create_#{@item[:type]}_import", IMPORT_STARTED)
      IMPORT_WORKERS[@item[:type]].perform_async import_data
      head 204
    rescue Exception => e
      Rails.logger.error "Exception while parsing csv file for contact/company 
                        import, message: #{e.message}, exception: #{e.backtrace}"
      render_errors INVALID_CSV_FILE_ERROR
    end

    def self.wrap_params
      WRAP_PARAMS
    end

    private

    def import_data
      @item[:customers][:file_location] = file_location
      @item[:customers][:file_name] = file_name
      @item
    end

    def import_exists?(type)
      current_account.send(:"#{type}_import").present?
    end

    def build_object
      @item = { 
        account_id: current_account.id,
        email: current_user.email,
        type: params[:type],
        customers: {
          fields: params[:fields]
        }
      }
    rescue Exception => e
      log_and_render_404
    end

    def valid_content_type?
      allowed_content_types = CustomerImportConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym] || [:json]
      allowed_content_types.include?(request.content_mime_type.ref)
    end

    def validate_filter_params
      params.permit(*VALID_INDEX_PARAMS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @import_filter = CustomerImportFilterValidation.new(params, nil, 
                                                        string_request_params?)
      render_errors(@import_filter.errors, @import_filter.error_options) unless @import_filter.valid?
    end

    def constants_class
      :CustomerImportConstants.to_s.freeze
    end

    def validate_params
      validate_body_params
    end

    wrap_parameters(*wrap_params)
  end
end
class OutOfOfficesController < ApiApplicationController
  include Admin::ShiftHelper
  include OutOfOfficeConstants

  skip_before_filter :load_object, :build_object
  before_filter :shift_service_request, only: %i[index show create update]

  def index; end

  def show; end

  def create; end

  def update; end

  def destroy
    head perform_shift_request(params, cname_params)[:code]
  end

  private

    def extended_url(action, out_of_office_id)
      case action
      when :index, :create
        OUT_OF_OFFICE_INDEX
      else
        format(OUT_OF_OFFICE_SHOW, out_of_office_id: out_of_office_id)
      end
    end

    def validate_params
      if params[cname].blank?
        render_errors([[:payload, :invalid_json]])
      else
        out_of_office_validation = out_of_office_validation_class.new(params[cname])
        if out_of_office_validation.valid?
          check_controller_params
        else
          render_errors(out_of_office_validation.errors, out_of_office_validation.error_options)
        end
      end
    end

    def check_controller_params
      params[cname].permit(*REQUEST_PERMITTED_PARAMS)
    end

    def out_of_office_validation_class
      'OutOfOfficeValidation'.constantize
    end

    def launch_party_name
      FeatureConstants::OUT_OF_OFFICE
    end
end

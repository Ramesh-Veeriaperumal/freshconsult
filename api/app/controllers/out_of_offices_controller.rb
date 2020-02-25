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

    def launch_party_name
      FeatureConstants::OUT_OF_OFFICE
    end
end

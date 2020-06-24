class AgentStatusesController < ApiApplicationController
  include Admin::ShiftHelper

  skip_before_filter :load_object, :build_object
  before_filter :shift_service_request, only: %i[index show create update]

  def index; end

  def show; end

  def create; end

  def update; end

  def destroy
    delete_response = perform_shift_request(params, cname_params)
    if success? delete_response[:code]
      head delete_response[:code]
    else
      response.status = delete_response[:code]
      @item = delete_response[:body]
    end
  end

  private

    def extended_url(_action, _id)
      request_path = request.path.gsub!('agent_statuses', 'agent-statuses')
      (request_path.gsub!('_', 'v1') || request_path.gsub('v2', 'v1')).last(-1)
    end

    def validate_filter_params; end

    def launch_party_name
      FeatureConstants::AGENT_STATUSES
    end
end

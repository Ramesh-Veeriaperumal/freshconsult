class AgentStatusesController < ApiApplicationController
  include Admin::ShiftHelper

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

    def extended_url(action, id)
      request_path = request.path.gsub!('agent_statuses', 'agent-statuses')
      (request_path.gsub!('_', 'v1') || request_path.gsub('v2', 'v1')).last(-1)
    end

    def validate_filter_params; end

    def launch_party_name
      FeatureConstants::AGENT_STATUSES
    end
end
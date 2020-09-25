# frozen_string_literal: true

class Channel::V2::GroupsController < ApiApplicationController
  include ChannelAuthentication
  include CentralLib::CentralResyncConstants
  include CentralLib::CentralResyncHelper
  skip_before_filter :check_privilege, :load_object, if: :skip_privilege_check?
  before_filter :channel_client_authentication, :validate_params, only: [:sync]

  def sync
    channel_source = @source
    if resync_worker_limit_reached?(channel_source)
      head 429
    else
      job_id = request.uuid
      persist_job_info_and_start_entity_publish(channel_source, job_id, RESYNC_ENTITIES[:group], @args[:meta])
      @response = {
        job_id: job_id
      }
      render status: :accepted
    end
  end

  private

    def skip_privilege_check?
      RESYNC_ALLOWED_SOURCE.any? { |source| channel_source?(source.to_sym) }
    end

    def validation_class
      Channel::V2::GroupsValidation
    end

    def validate_params
      @args = params.symbolize_keys
      groups_validation = validation_class.new(@args)
      render_custom_errors(groups_validation, true) unless groups_validation.valid?(action_name.to_sym)
    end
end

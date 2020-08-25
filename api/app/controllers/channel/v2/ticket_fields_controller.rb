# frozen_string_literal: true

class Channel::V2::TicketFieldsController < ApiApplicationController
  include ChannelAuthentication
  include CentralLib::CentralResyncConstants
  include CentralLib::CentralResyncRateLimiter
  include CentralLib::CentralResyncHelper

  skip_before_filter :check_privilege, if: :skip_privilege_check?
  skip_before_filter :load_object
  before_filter :channel_client_authentication
  before_filter :validate_params, only: [:sync]

  def sync
    channel_source = @source
    if resync_worker_limit_reached?(channel_source)
      head 429
    else
      job_id = request.uuid
      persist_job_info_and_start_entity_publish(channel_source, job_id, RESYNC_ENTITIES[:ticket_field], @args[:meta])
      @response = {
        job_id: job_id
      }
      render status: 202
    end
  end

  private

    def skip_privilege_check?
      TICKET_FIELDS_ALLOWED_SOURCE.each do |source|
        return true if channel_source?(source.to_sym)
      end
      false
    end

    def validation_class
      Channel::V2::TicketFieldsValidation
    end

    def validate_params
      @args = params.symbolize_keys
      ticket_fields_validation = validation_class.new(@args)
      unless ticket_fields_validation.valid?(action_name.to_sym)
        render_custom_errors(ticket_fields_validation, true)
      end
    end
end

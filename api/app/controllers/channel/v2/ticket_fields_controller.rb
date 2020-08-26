# frozen_string_literal: true

class Channel::V2::TicketFieldsController < Channel::V2::CentralResyncController

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

    def validation_class
      Channel::V2::TicketFieldsValidation
    end

    def validate_params
      @args = params.symbolize_keys
      ticket_fields_validation = validation_class.new(@args)
      render_custom_errors(ticket_fields_validation, true) unless ticket_fields_validation.valid?(action_name.to_sym)
    end
end

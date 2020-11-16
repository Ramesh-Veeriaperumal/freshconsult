module Tickets
  class BulkActionsController < ApiApplicationController
    include BulkActionConcern
    include BulkApiJobsHelper
    include TicketConcern
    include HelperConcern
    include Redis::RedisKeys

    before_filter :archive_disabled?, :setting_enabled?, only: [:bulk_archive]

    def bulk_archive
      @validation_klass = 'ArchiveValidation'
      params_hash = params[cname].merge(skip_bulk_validations: true)
      return unless validate_body_params(nil, params_hash) && validate_archive_delegator

      archive_tickets
      head 204
    end

    def bulk_delete
      return render_request_error :missing_param, 400 if params[cname].blank? || params[cname].empty?

      return unless validate_bulk_action_params

      @job_id = request.uuid
      initiate_bulk_job(ApiTicketConstants::BULK_API_JOBS_CLASS, params[cname], @job_id, action_name)
      @job_link = current_account.bulk_job_url(@job_id)
      render('bulk_api_jobs/response', status: 202) if @errors.blank?
    end

    private

      def archive_tickets
        Archive::AccountTicketsWorker.perform_async(
          account_id: current_account.id,
          archive_days: cname_params[:archive_days] ||
                          (cname_params[:ids].present? && 0) || # If the user prefers to send ticket_ids, there is no need to expect archive_days
                          current_account.account_additional_settings.archive_days,
          ticket_status: :closed,
          display_ids: cname_params[:ids]
        )
      end

      def validate_archive_delegator
        @delegator_klass = 'ArchiveDelegator'
        if cname_params[:ids].present?
          delegator_params = {
            ids: cname_params[:ids],
            permissible_ids: permissible_ticket_ids(cname_params[:ids])
          }
          return validate_delegator(@item, delegator_params)
        end
        true
      end

      def archive_disabled?
        render_request_error :access_denied, 403 if current_account.disable_archive_enabled?
      end

      def setting_enabled?
        render_request_error(:require_feature, 403, feature: FeatureConstants::ARCHIVE_API.to_s.titleize) unless current_account.archive_tickets_api_enabled?
      end

      def constants_class
        :ApiTicketConstants.to_s.freeze
      end

      def scoper
        current_account.tickets
      end
  end
end

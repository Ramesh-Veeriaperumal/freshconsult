module Channel::V2::Tickets
  class BulkActionsController < ::Tickets::BulkActionsController
    private

      def archive_tickets
        Archive::AccountTicketsChannelWorker.perform_async(
          account_id: current_account.id,
          archive_days: cname_params[:archive_days] ||
                          (cname_params[:ids].present? && 0) || # If the user prefers to send ticket_ids, there is no need to expect archive_days
                          current_account.account_additional_settings.archive_days,
          ticket_status: :closed,
          display_ids: cname_params[:ids]
        )
      end
  end
end

module Archive
  class TicketWorker < BaseWorker
    include Utils::Freno
    sidekiq_options queue: ::ArchiveSikdekiqConfig['archive_ticket'], retry: 2, failures: :exhausted
    APPLICATION_NAME="ArchiveWorker"

    def perform(args)
      @account = Account.current
      @args = HashWithIndifferentAccess.new(args)
      return unless valid_archive_request?(@args[:ticket_id])

      shard_name = Sharding.select_shard_of @account.id do
        ActiveRecord::Base.current_shard_selection.shard.to_s
      end

      #Check for any replication lag detected by Freno for the current account's shard in DB.
      lag_seconds = get_replication_lag_for_shard(APPLICATION_NAME, shard_name)
      if (lag_seconds > 0) then
        Rails.logger.debug("Warning: replication lag: #{lag_seconds} secs :: ticket:: #{@args[:ticket_id]} shard :: #{shard_name}")
        Archive::TicketWorker.perform_in(lag_seconds.seconds.from_now, @args)
        return
      else
        Sharding.run_on_master do
          create_archive_ticket_with_body
          modify_ticket_associations
          delete_ticket_with_dependencies
        end
      end
      rescue MissionAssociationError => e
        Rails.logger.debug("Error while archiving ticket :: #{e.message} :: #{@args.inspect} :: #{e.backtrace[0..5].inspect}")
        raise e
      rescue Exception => e
        Rails.logger.debug("Error while archiving ticket :: #{e.message} :: #{@args.inspect} :: #{e.backtrace}")
    end

    private

      def valid_archive_request?(ticket_id)
        return if @account.launched?(:disable_archive)

        @ticket = @account.tickets.find(ticket_id)
        @archive_days = @args['archive_days'] || @account.account_additional_settings.archive_days
        @ticket && @ticket.closed? && (@ticket.updated_at < @archive_days.days.ago)
      end

      def create_archive_ticket_with_body
        @ticket.reset_associations if @ticket.association_type
        @archive_core_base = Archive::Core::Base.new
        @archive_ticket = @account.archive_tickets.find_by_ticket_id_and_progress(@ticket.id, true) ||
                          @archive_core_base.create_archive_ticket(@ticket)
        @archive_core_base.create_archive_ticket_body(@archive_ticket, @ticket)
      end

      def modify_ticket_associations
        return unless @archive_ticket && @archive_ticket.progress

        @archive_core_base.modify_archive_ticket_association(@ticket, @archive_ticket)
        split_notes
      end

      def split_notes
        @ticket.notes.each do |note|
          archive_note = @account.archive_notes.find_by_note_id(note.id) ||
                         @archive_core_base.create_archive_note(note, @archive_ticket)
          @archive_core_base.create_note_body_association(note, archive_note, @archive_ticket)
          @archive_core_base.modify_archive_note_association(note, archive_note)
        end
      end

      def delete_ticket_with_dependencies
        return unless @archive_ticket

        @archive_core_base.delete_ticket(@ticket, @archive_ticket)
      end
  end
end

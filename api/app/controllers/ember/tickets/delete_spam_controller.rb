module Ember
  module Tickets
    class DeleteSpamController < ApiApplicationController
      include TicketConcern
      include DeleteSpamConcern
      include Redis::RedisKeys

      def empty_trash
        clear_all
        head 204
      end

      def empty_spam
        clear_all(true)
        head 204
      end

      def delete_forever
        bulk_action do
          @items_failed = []
          @items.each do |item|
            @items_failed << item unless item.deleted
          end
          clear_selected(false, @items.map(&:id) - @items_failed.map(&:id))
        end
      end

      def delete_forever_spam
        bulk_action do
          @items_failed = []
          @items.each do |item|
            @items_failed << item unless item.spam
          end
          clear_selected(true, @items.map(&:id) - @items_failed.map(&:id))
        end
      end

      private

        def scoper
          current_account.tickets
        end

        def fetch_objects(items = scoper)
          @items = items.preload(preload_options).find_all_by_param(permissible_ticket_ids(params[cname][:ids]))
        end

        def preload_options
          if ApiTicketConstants::REQUIRE_PRELOAD.include?(action_name.to_sym)
            ApiTicketConstants::BULK_DELETE_PRELOAD_OPTIONS
          end
        end

        def load_object
          @item = scoper.find_by_display_id(params[:id])
          log_and_render_404 unless @item
        end

        def after_load_object
          verify_ticket_state_and_permission
        end

        def clear_all(spam = false)
          key = spam ? empty_spam_key : empty_trash_key
          set_tickets_redis_key(key, true, 1.day)
          clear_tickets_async(spam, clear_all: true)
        end

        def clear_selected(spam = false, ticket_ids = [])
          flag_trashed(ticket_ids)
          clear_tickets_async(spam, ticket_ids: ticket_ids)
        end

        def clear_tickets_async(spam, args)
          worker = spam ? ::Tickets::ClearTickets::EmptySpam : ::Tickets::ClearTickets::EmptyTrash
          worker.perform_async(args)
        end

        def flag_trashed(items)
          Helpdesk::SchemaLessTicket.where('ticket_id IN (?)', items).update_all(Helpdesk::SchemaLessTicket.trashed_column => true)
        end

        def empty_trash_key
          EMPTY_TRASH_TICKETS % { account_id: current_account.id }
        end

        def empty_spam_key
          EMPTY_SPAM_TICKETS % { account_id: current_account.id }
        end
    end
  end
end

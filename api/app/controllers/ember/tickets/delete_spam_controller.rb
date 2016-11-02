module Ember
  module Tickets
    class DeleteSpamController < ApiApplicationController
      include TicketConcern
      include BulkActionConcern
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
          @items = items.find_all_by_param(permissible_ticket_ids(params[cname][:ids]))
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

        def bulk_action_errors
          @bulk_action_errors ||=
            params[cname][:ids].inject([]) do |a, e|
              error_hash = retrieve_error_code(e)
              error_hash.any? ? a << error_hash : a
            end
        end

        def retrieve_error_code(id)
          ret_hash = { id: id, errors: {}, error_options: {} }
          if bulk_action_failed_items.include?(id)
            ret_hash[:errors][:id] = :unable_to_perform
          elsif !bulk_action_succeeded_items.include?(id)
            ret_hash[:errors][:id] = :"is invalid"
          else
            return {}
          end
          ret_hash
        end

        def bulk_action_succeeded_items
          @succeeded_ids ||= @items.map(&:display_id) - bulk_action_failed_items
        end

        def bulk_action_failed_items
          @failed_ids ||= (@items_failed || []).map(&:display_id)
        end
    end
  end
end

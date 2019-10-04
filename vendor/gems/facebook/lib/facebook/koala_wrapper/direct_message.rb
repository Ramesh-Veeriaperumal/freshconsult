module Facebook
  module KoalaWrapper
    class DirectMessage
      include Facebook::Constants
      include TicketActions::DirectMessage

      def initialize(fan_page)
        @account  = Account.current
        @fan_page = fan_page
        @threads_fetcher = Facebook::DataFetcher::ThreadsFetcher.new(fan_page)
      end

      # fetching message threads
      def fetch_messages
        all_threads = @threads_fetcher.fetch_threads

        # To avoid missing out older threads, we loop and hit the API until we receive an older value
        while @threads_fetcher.next_page?
          all_threads += @threads_fetcher.fetch_next_page
        end
        updated_time = all_threads.collect { |thread| thread['updated_time'] }.compact.max
        create_tickets(all_threads)
        @fan_page.update_attributes(message_since: Time.parse(updated_time).to_i) if updated_time.present?
      end
    end
  end
end

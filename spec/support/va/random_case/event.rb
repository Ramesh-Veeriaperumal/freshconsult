module VA::RandomCase
  module Event

    def define_options
      @options = {
        :priority     => { :feed_data => { :from => fetch_random_unique_choice(:priority),     :to => fetch_random_unique_choice(:priority) } },
        :ticket_type  => { :feed_data => { :from => fetch_random_unique_choice(:ticket_type),  :to => fetch_random_unique_choice(:ticket_type) } },
        :status       => { :feed_data => { :from => fetch_random_unique_choice(:status),       :to => fetch_random_unique_choice(:status) } },
        :group_id     => { :feed_data => { :from => fetch_random_unique_choice(:group_id),     :to => fetch_random_unique_choice(:group_id) } },
        :responder_id => { :feed_data => { :from => fetch_random_unique_choice(:responder_id), :to => fetch_random_unique_choice(:responder_id) } },
        :note_type    => { :feed_data => { :value => fetch_random_unique_choice(:note_type) } },
        :reply_sent   => { :feed_data => { :value => 'sent' } },
        :due_by       => { :feed_data => { :from => Time.now-1, :to => Time.now } },
        :customer_feedback  => { :feed_data => { :value => fetch_random_unique_choice(:customer_feedback) } },
        :time_sheet_action  => { :feed_data => { :value => fetch_random_unique_choice(:time_sheet_action) } }
      }
      @option_exceptions = {
        :ticket_action=> { :feed_data => { :value => fetch_random_unique_choice(:ticket_action) }, :exception => true }
        }
    end

    private

      def event_tester
        @event_tester||= VA::Tester::Event.new event_defs
      end

      def fetch_random_unique_choice option
        event_tester.fetch_random_unique_choice option
      end

  end
end
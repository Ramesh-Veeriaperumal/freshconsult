module VA::RandomCase
  module Condition
    module Supervisor

      def define_options
        @options = {
          :from_email   => { :feed_data => { :value => [Faker::Internet.email, @requester.email].sample } },
          :to_email     => { :feed_data => { :value => [Faker::Internet.email, @to_email].sample } },
          :subject      => { :feed_data => { :value => [Faker::Lorem.sentence(3), @ticket.subject].sample } },
          :priority     => { :feed_data => { :value => fetch_random_unique_choice(:priority) } },
          :ticket_type  => { :feed_data => { :value => fetch_random_unique_choice(:ticket_type) } },
          :status       => { :feed_data => { :value => fetch_random_unique_choice(:status) } },
          :source       => { :feed_data => { :value => fetch_random_unique_choice(:source) } },
          :product_id   => { :feed_data => { :value => fetch_random_unique_choice(:product_id) } },
          :responder_id => { :feed_data => { :value => fetch_random_unique_choice(:responder_id) } },
          :group_id     => { :feed_data => { :value => fetch_random_unique_choice(:group_id) } },
          :contact_name => { :feed_data => { :value => [Faker::Name.name, @requester.name].sample } },
          :company_name => { :feed_data => { :value => [Faker::Company.name, @company.name].sample } },
          :inbound_count  => { :feed_data => { :value => [0,1].sample } },
          :outbound_count => { :feed_data => { :value => [0,1].sample } },
          # :created_at    => { :feed_data => { :value => 1 } }, # not testing this, need to restructure OPTIONS
          :pending_since => { :feed_data => { :value => [0,1,2].sample } },
          :resolved_at   => { :feed_data => { :value => [0,1,2].sample } },
          :closed_at     => { :feed_data => { :value => [0,1,2].sample } },
          :opened_at     => { :feed_data => { :value => [0,1,2].sample } },
          :assigned_at   => { :feed_data => { :value => [0,1,2].sample } },
          :requester_responded_at => { :feed_data => { :value => [0,1,2].sample } },
          :first_assigned_at  => { :feed_data => { :value => [0,1,2].sample } },
          :agent_responded_at => { :feed_data => { :value => [0,1,2].sample } },
          :frDueBy => { :feed_data => { :value => [0,1,2].sample } },
          :due_by  => { :feed_data => { :value => [0,1,2].sample } },
        }
        @option_exceptions = {}
      end

      private

        def condition_tester
          @condition_tester||= VA::Tester::Condition::Supervisor.new filter_defs
        end

        def fetch_random_unique_choice option
          condition_tester.fetch_random_unique_choice option
        end

    end
  end
end
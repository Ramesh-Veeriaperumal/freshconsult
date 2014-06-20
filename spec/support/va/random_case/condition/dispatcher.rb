module VA::RandomCase
  module Condition
    module Dispatcher

      def define_options
        @options = {
          :from_email   => { :feed_data => { :value => [Faker::Internet.email, @requester.email].sample } },
          :to_email     => { :feed_data => { :value => [Faker::Internet.email, @to_email].sample } },
          :ticlet_cc    => { :feed_data => { :value => [Faker::Internet.email, @ticlet_cc].sample } },
          :subject      => { :feed_data => { :value => [Faker::Lorem.sentence(3), @ticket.subject].sample } },
          :description  => { :feed_data => { :value => [Faker::Lorem.paragraph(3), @ticket.description].sample } },
          :last_interaction => { :feed_data => { :value => [Faker::Lorem.paragraph(3), @ticket.notes.last.body].sample } },
          :priority     => { :feed_data => { :value => fetch_random_unique_choice(:priority) } },
          :ticket_type  => { :feed_data => { :value => fetch_random_unique_choice(:ticket_type) } },
          :status       => { :feed_data => { :value => fetch_random_unique_choice(:status) } },
          :source       => { :feed_data => { :value => fetch_random_unique_choice(:source) } },
          :product_id   => { :feed_data => { :value => fetch_random_unique_choice(:product_id) } },
          :created_at   => { :feed_data => { :value => [:business_hours, :non_business_hours, :holidays].sample } },
          :responder_id => { :feed_data => { :value => fetch_random_unique_choice(:responder_id) } },
          :group_id     => { :feed_data => { :value => fetch_random_unique_choice(:group_id) } },
          :contact_name => { :feed_data => { :value => [Faker::Name.name, @ticket.requester.name].sample } },
          :company_name => { :feed_data => { :value => [Faker::Company.name, @ticket.requester.customer.name].sample } },
          :inbound_count  => { :feed_data => { :value => [0,1].sample } },
          :outbound_count => { :feed_data => { :value => [0,1].sample } }
        }
        @option_exceptions = {
          :subject_or_description => { :feed_data => 
            { :value => [@ticket.subject, @ticket.description].sample }, :exception => true
              }
        }
      end

      private

        def condition_tester
          @condition_tester||= VA::Tester::Condition::Dispatcher.new filter_defs
        end

        def fetch_random_unique_choice option
          condition_tester.fetch_random_unique_choice option
        end

    end
  end
end
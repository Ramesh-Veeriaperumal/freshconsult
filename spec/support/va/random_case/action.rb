module VA::RandomCase
  module Action

    def define_options
      @options = {
        :priority      => { :feed_data => { :value => fetch_random_unique_choice(:priority) } },
        :ticket_type   => { :feed_data => { :value => fetch_random_unique_choice(:ticket_type) } },
        :status        => { :feed_data => { :value => fetch_random_unique_choice(:status) } },
        :add_tag       => { :feed_data => { :value => Faker::Lorem.words(1).first }, :check_against => [:tags, :last, :name] },
        :add_a_cc      => { :feed_data => { :value => Faker::Internet.email },  :check_against => [:ticlet_cc, :last] },
        :add_watcher   => { :feed_data => { :value => fetch_random_unique_choice(:add_watcher).to_s }, :check_against => [:subscriptions, :last, :user_id, :to_s] },
        :responder_id  => { :feed_data => { :value => fetch_random_unique_choice(:responder_id) } },
        :group_id      => { :feed_data => { :value => fetch_random_unique_choice(:group_id) } },
        :product_id    => { :feed_data => { :value => fetch_random_unique_choice(:product_id) } },
        :delete_ticket => { :feed_data => { :value => true }, :check_against => [:deleted] },
        :mark_as_spam  => { :feed_data => { :value => true }, :check_against => [:spam] }
      }
      @option_exceptions = { 
        :add_comment             => { :feed_data => { :comment => Faker::Lorem.sentence(100), :private => 'true'}, :exception => true  },
        :send_email_to_group     => { :feed_data => { :value => Faker::Lorem.paragraph(10) }, :exception => true },
        :send_email_to_agent     => { :feed_data => { :value => Faker::Lorem.paragraph(10) }, :exception => true },
        :send_email_to_requester => { :feed_data => { :value => Faker::Lorem.paragraph(10) }, :exception => true },
        :skip_notification       => { :feed_data => { :value => nil }, :exception => true },
        :trigger_webhook         => { :feed_data => { :name => 'trigger_webhook',
                                                      :request_type => '2',
                                                      :url => 'http://localhost.freshdesk-dev.com',
                                                      :need_authentication => "true",
                                                      :username => 'sample@freshdesk.com',
                                                      :password => 'test',
                                                      :content_type => "2",
                                                      :content_layout => "1",
                                                      :params => {
                                                        'ticket_id' => "{{ticket.id}}",
                                                        'ticket_subject' => "{{ticket.subject}}",
                                                        'ticket_description' => "{{ticket.description}}",
                                                        'ticket_url' => "{{ticket.url}}",
                                                        'ticket_public_url' => "{{ticket.public_url}}",
                                                        'ticket_portal_url' => "{{ticket.portal_url}}",
                                                        ':ticket_status' => "{{ticket.status}}",
                                                        'ticket_priority' => "{{ticket.priority}}",
                                                        'ticket_source' => "{{ticket.source}}",
                                                        'ticket_type' => "{{ticket.ticket_type}}",
                                                        'ticket_tags' => "{{ticket.tags}}",
                                                        'ticket_due_by_time' => "{{ticket.due_by_time}}",
                                                        'ticket_requester_name' => "{{ticket.requester.name}}",
                                                        'ticket_requester_firstname' => "{{ticket.requester.firstname}}",
                                                        'ticket_requester_lastname' => "{{ticket.requester.lastname}}",
                                                        'ticket_requester_email' => "{{ticket.from_email}}",
                                                        'ticket_requester_company_name' => "{{ticket.requester.company_name}}",
                                                        'ticket_requester_phone' => "{{ticket.requester.phone}}",
                                                        'ticket_requester_address' => "{{ticket.requester.address}}",
                                                        'ticket_group_name' => "{{ticket.group.name}}",
                                                        'ticket_agent_name' => "{{ticket.agent.name}}",
                                                        'ticket_agent_email' => "{{ticket.agent.email}}",
                                                        'ticket_latest_public_comment' => "{{ticket.latest_public_comment}}",
                                                        'helpdesk_name' => "{{helpdesk_name}}",
                                                        'ticket_portal_name' => "{{ticket.portal_name}}",
                                                        'ticket_product_description' => "{{ticket.product_description}}",
                                                        'contact_primary_email' => "{{ticket.requester.email}}",
                                                        'triggered_event' => "{{triggered_event}}"
                                                      }
                                                    }, :exception => true
                                                  }
      }
    end

    private

      def action_tester
        @action_tester||= VA::Tester::Action.new action_defs
      end

      def fetch_random_unique_choice option
        action_tester.fetch_random_unique_choice option
      end

  end
end
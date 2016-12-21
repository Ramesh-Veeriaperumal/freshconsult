module Fixtures
  module DefaultObserver
    def create_rule
      account = Account.current

      VaRule.seed_many(:account_id, :name, :rule_type, [
        [ 'Automatically assign ticket to first responder', 
          'When an agent replies to, or adds a note to an unassigned ticket, it gets assigned to him/her automatically.',
          1,
          {
            :events => [
              { :name => 'reply_sent' },
              { :value => 'public', :name => 'note_type'  }
              ],
              :performer => { :type => Va::Performer::AGENT },
              :conditions => [
                {:evaluate_on => "ticket", :value => [""], :operator => 'in', :name => 'responder_id' }
              ]
              },
              [ 
                { :name => 'responder_id', :value => Va::Action::EVENT_PERFORMER }
              ]
              ],
              [ 'Automatically reopen tickets when the customer responds', 
                "When a requester replies to a ticket in any state (pending, resolved, closed or a custom status), its status is changed back to open.",
                2,
                {
                  :events => [
                    { :name => 'reply_sent' }
                    ],
                    :performer => { :type => Va::Performer::CUSTOMER },
                    :conditions => [
                      {:evaluate_on => "ticket", :value => ["2"], :operator => 'not_in', :name => 'status' }
                    ]
                    },
                    [
                      { :name => 'status', :value => Helpdesk::Ticketfields::TicketStatus::OPEN},
                      {
                        :email_to => Va::Action::ASSIGNED_AGENT,
                        :name => 'send_email_to_agent',
                        :email_body => '<p>Hi {{ticket.agent.name}},<br /><br />Ticket "#{{ticket.id}} - {{ticket.subject}}" has been reopened, please visit {{ticket.url}} to view the ticket.<br /><br />Ticket comment<br />{{comment.body}}</p>',
                        :email_subject => 'Ticket re-opened - [#{{ticket.id}}] {{ticket.subject}}'
                      }
                    ]
                  ]
                  ].map do |f|
                    {
                      :account_id => account.id,
                      :rule_type => VAConfig::OBSERVER_RULE,
                      :active => true,
                      :match_type => 'any',
                      :name => f[0],
                      :description => f[1],
                      :position => f[2],
                      :filter_data => f[3],
                      :action_data => f[4]
                    }
                  end
                  )

    end
    module_function :create_rule
  end
end
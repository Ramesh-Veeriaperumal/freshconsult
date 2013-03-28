account = Account.current

VARule.seed_many(:account_id, :name, :rule_type, [
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
                          { :value => nil, :operator => 'is', :name => 'responder_id' }
                      ]
      },
      [ 
        { :name => 'responder_id', :value => Va::Action::EVENT_PERFORMER }
      ]
    ],
    [ 'Automatically reopen closed tickets after a response', 
      "When a requester replies to a ticket that is resolved or closed, it's status is changed back to open.",
      2,
      {
        :events => [
                      { :name => 'reply_sent' },
                      { :value => 'public', :name => 'note_type'  }
                    ],
        :performer => { :type => Va::Performer::CUSTOMER },
        :conditions => [
                          { :value => Helpdesk::Ticketfields::TicketStatus::RESOLVED, :operator => 'is', :name => 'status' },
                          { :value => Helpdesk::Ticketfields::TicketStatus::CLOSED, :operator => 'is', :name => 'status' }
                      ]
      },
      [
        { :name => 'status', :value => Helpdesk::Ticketfields::TicketStatus::OPEN},
        {
          :email_to => Va::Action::ASSIGNED_AGENT,
          :name => 'send_email_to_agent',
          :email_body => '<p>Hi {{ticket.agent.name}},<br /><br />Ticket "#{{ticket.id}} - {{ticket.subject}}" has been reopened, please visit {{ticket.url}} to view the ticket.<br /><br />Ticket comment<br />{{comment.body}}</p>'
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

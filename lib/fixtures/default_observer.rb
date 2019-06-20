module Fixtures
  module DefaultObserver
    def create_rule
      account = Account.current

      auto_assign_filter_data = {
        :events => [
          {:name => 'reply_sent'},
          {:value => 'public', :name => 'note_type'}
        ],
        :performer => {:type => Va::Performer::AGENT},
        :conditions => [
          {:evaluate_on => "ticket", :value => [""], :operator => 'in', :name => 'responder_id'}
        ]
      }

      condition_data_hash = { 
        events: [
          { name: 'reply_sent' },
          { value: 'public', name: 'note_type' }
        ],
        performer: { type: Va::Performer::AGENT },
        conditions: { any: [{ evaluate_on: 'ticket', value: [''],
                              operator: 'in', name: 'responder_id' }] } }

      auto_assign_action_data = [
        {:name => 'responder_id', :value => Va::Action::EVENT_PERFORMER}
      ]

      VaRule.seed(:account_id, :name) do |s|
        s.account_id = account.id
        s.name =  'Automatically assign ticket to first responder'
        s.description = 'When an agent replies to, or adds a note to an unassigned ticket, it gets assigned to him/her automatically.'
        s.rule_type = VAConfig::OBSERVER_RULE
        s.match_type = 'any'
        s.position = 1
        s.active = true
        s.filter_data = auto_assign_filter_data
        s.action_data = auto_assign_action_data
        s.condition_data = condition_data_hash
      end

      ticket_reopen_filter_data = {
        :events => [
          { :name => 'reply_sent' }
        ],
        :performer => { :type => Va::Performer::CUSTOMER },
        :conditions => [
          {:evaluate_on => "ticket", :value => ["2"], :operator => 'not_in', :name => 'status' }
        ]
      }

      conditions = account.detect_thank_you_note_enabled? ?
                    { any: [{ any: [{ evaluate_on: :ticket, name: 'status',
                                     operator: 'not_in', value: [4, 5] }] },
                           { all: [{ evaluate_on: :ticket, name: 'freddy_suggestion',
                                    operator: 'is_not', value: 'thank_you_note' },
                                  { evaluate_on: :ticket, name: 'status', operator: 'in',
                                    value: [4, 5] }] }] } :
                    { any: [{ evaluate_on: 'ticket', value: ['2'],
                              operator: 'not_in', name: 'status' }] }

      ticket_reopen_condition_data = {
        events: [
          { name: 'reply_sent' }
        ],
        performer: { type: Va::Performer::CUSTOMER },
        conditions: conditions
      }

      ticket_reopen_action_data = [
        { :name => 'status', :value => Helpdesk::Ticketfields::TicketStatus::OPEN },
        {
          :email_to => Va::Action::ASSIGNED_AGENT,
          :name => 'send_email_to_agent',
          :email_body => '<p>Hi {{ticket.agent.name}},<br /><br />Ticket "#{{ticket.id}} - {{ticket.subject}}" has been reopened, please visit {{ticket.url}} to view the ticket.<br /><br />Ticket comment<br />{{comment.body}}</p>',
          :email_subject => 'Ticket re-opened - [#{{ticket.id}}] {{ticket.subject}}'
        }
      ]

      ticket_reopen_rule = account.va_rules.new(
          :rule_type => VAConfig::OBSERVER_RULE,
          :active => account.verified?,
          :match_type => 'any',
          :name => 'Automatically reopen tickets when the customer responds',
          :description => "When a requester replies to a ticket in any state (pending, resolved, closed or a custom status), its status is changed back to open.",
          :position => 2,
          )

      ticket_reopen_rule.filter_data = ticket_reopen_filter_data
      ticket_reopen_rule.action_data = ticket_reopen_action_data
      ticket_reopen_rule.condition_data = ticket_reopen_condition_data
      ticket_reopen_rule.save!(:validate => false) #It should skip any_restricted_actions? validation for the default rule.
      
    end
    module_function :create_rule
  end
end
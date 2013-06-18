class CreateDefaultObserverRules < ActiveRecord::Migration
  def self.up
  	Account.all.each do |account|
      account.all_observer_rules.create({ 
      	:name => 'Automatically assign ticket to first responder', 
  			:description =>  'When an agent replies to, or adds a note to an unassigned ticket, it gets assigned to him/her automatically.',
   			:rule_type => VAConfig::OBSERVER_RULE,
   			:match_type => 'any',
    		:filter_data =>  {
        	:events => [
                      { :name => 'reply_sent' },
                      { :value => 'public', :name => 'note_type'  }
                    ],
        	:performer => { :type => Va::Performer::AGENT },
        	:conditions => [
                          { :value => nil, :operator => 'is', :name => 'responder_id' }
                      	]
      	},
		    :action_data => [ 
		      { :name => 'responder_id', :value => Va::Action::EVENT_PERFORMER }
      								],
      	:active => true
			})

      ticket_reopening_notification = account.email_notifications.find_by_notification_type(9) if account.email_notifications
      if ticket_reopening_notification.agent_notification?
  			account.all_observer_rules.create!({
  				:name => 'Automatically reopen closed tickets after a response', 
        	:description => "When a requester replies to a ticket that is resolved or closed, it's status is changed back to open.",
        	:rule_type => VAConfig::OBSERVER_RULE,
        	:match_type => 'any',
  	      :filter_data =>  {
  	        :events => [
  	                      { :name => 'reply_sent' },
  	                      { :value => 'public', :name => 'note_type' }
  	                    ],
  	        :performer => { :type => Va::Performer::CUSTOMER },
  	        :conditions => [
  	                          { :value => Helpdesk::Ticketfields::TicketStatus::RESOLVED, :operator => 'is', :name => 'status' },
  	                          { :value => Helpdesk::Ticketfields::TicketStatus::CLOSED, :operator => 'is', :name => 'status' }
  	                      ]
  	      },
        	:action_data => [ 
  	        { :name => 'status', :value => Helpdesk::Ticketfields::TicketStatus::OPEN },
  	        {
  	          :email_to => Va::Action::ASSIGNED_AGENT,
  	          :name => 'send_email_to_agent',
  	          :email_body => ticket_reopening_notification.agent_template,
              :email_subject => ticket_reopening_notification.agent_subject_template
  	        }
        	],
        	:active => true
  			})
      end
    end
  end

  def self.down
  end
end

module Va
  module Constants
    TIME_BASED_FILTERS = [
      { :name => -1, :value => "-----------------------"  },
      { :name => "created_at", :value => I18n.t('ticket.created_at'), :domtype => "number",
        :operatortype => "hours" },
      { :name => "pending_since", :value => I18n.t('ticket.pending_since'), :domtype => "number",
        :operatortype => "hours" },
      { :name => "resolved_at", :value => I18n.t('ticket.resolved_at'), :domtype => "number",
        :operatortype => "hours" },
      { :name => "closed_at", :value => I18n.t('ticket.closed_at'), :domtype => "number",
        :operatortype => "hours" },
      { :name => "opened_at", :value => I18n.t('ticket.opened_at'), :domtype => "number",
        :operatortype => "hours" },
      { :name => "first_assigned_at", :value => I18n.t('ticket.first_assigned_at'), 
        :domtype => "number", :operatortype => "hours" },
      { :name => "assigned_at", :value => I18n.t('ticket.assigned_at'), :domtype => "number",
        :operatortype => "hours" },
      { :name => "requester_responded_at", :value => I18n.t('ticket.requester_responded_at'), 
        :domtype => "number", :operatortype => "hours" },
      { :name => "agent_responded_at", :value => I18n.t('ticket.agent_responded_at'), 
        :domtype => "number", :operatortype => "hours" },
      { :name => "first_response_time", :value => I18n.t('ticket.first_response_due'), 
        :domtype => "number", :operatortype => "hours" },
      { :name => "due_by", :value => I18n.t('ticket.due_by'), :domtype => "number",
        :operatortype => "hours" }
    ]

    TICKET_STATE_FILTERS = [
      { :name => -1, :value => "-----------------------"  },
      { :name => "inbound_count", :value => I18n.t('ticket.inbound_count'), :domtype => "number",
        :operatortype => "hours" },
      { :name => "outbound_count", :value => I18n.t('ticket.outbound_count'), :domtype => "number",
        :operatortype => "hours" }
    ]
    
    OPERATOR_TYPES = {
      :email       => [ "is", "is_not", "contains", "does_not_contain" ],
      :text        => [ "is", "is_not", "contains", "does_not_contain", "starts_with", "ends_with" ],
      :checkbox    => [ "selected", "not_selected" ],
      :choicelist  => [ "is", "is_not" ],
      :number      => [ "is", "is_not" ],
      :hours       => [ "is", "greater_than", "less_than" ],
      :nestedlist  => [ "is" ],
      :greater     => [ "greater_than" ],
      :object_id   => [ "is" ],
      :date_time     => [ "during" ]
    }

    CF_OPERATOR_TYPES = {
      "custom_dropdown" => "choicelist",
      "custom_checkbox" => "checkbox",
      "custom_number"   => "number",
      "nested_field"    => "nestedlist",
    }

    OPERATOR_LIST =  {
      :is                =>  I18n.t('is'),
      :is_not            =>  I18n.t('is_not'),
      :contains          =>  I18n.t('contains'),
      :does_not_contain  =>  I18n.t('does_not_contain'),
      :starts_with       =>  I18n.t('starts_with'),
      :ends_with         =>  I18n.t('ends_with'),
      :between           =>  I18n.t('between'),
      :between_range     =>  I18n.t('between_range'),
      :selected          =>  I18n.t('selected'),
      :not_selected      =>  I18n.t('not_selected'),
      :less_than         =>  I18n.t('less_than'),
      :greater_than      =>  I18n.t('greater_than'),
      :during            =>  I18n.t('during')
    }

  end
end
module TicketsFilter
  include TicketConstants
  
  DEFAULT_FILTER = :new_and_my_open

  SELECTORS = [
    [:new_and_my_open,  "New & My Open Tickets", [:visible]  ],
    [:my_open,          "My Open Tickets", [:visible]  ],
    [:my_resolved,      "My Resolved Tickets", [:visible] ],
    [:my_closed,        "My Closed Tickets", [:visible]  ],
    [:my_due_today,     "My Tickets Due Today", [:visible]  ],
    [:my_overdue,       "My Overdue Tickets", [:visible]  ],
    [:my_on_hold,       "My Tickets On Hold", [:visible]  ],
    [:monitored_by,     "Tickets I'm Monitoring", [:visible]  ],
    [:my_all,           "All My Tickets", [:visible]  ],
    
    [:new,              "New Tickets", [:visible]  ],
    [:open,             "Open Tickets", [:visible]  ],
    [:new_and_open,     "New & Open Tickets", [:visible]  ],
    [:resolved,         "Resolved Tickets", [:visible]  ],
    [:closed,           "Closed Tickets", [:visible]  ],
    [:due_today,        "Tickets Due Today", [:visible]  ],
    [:overdue,          "Overdue Tickets", [:visible]  ],
    [:on_hold,          "Tickets On Hold", [:visible]  ],
    [:all,              "All Tickets ", [:visible]  ],
    
    [:spam,             "Spam"  ],
    [:deleted,          "Trash"  ]
  ]
  
  SELECTOR_NAMES = Hash[*SELECTORS.inject([]){ |a, v| a += [v[0], v[1]] }]
  ADDITIONAL_FILTERS = Hash[*SELECTORS.inject([]){ |a, v| a += [v[0], v[2]] }]
  
  SEARCH_FIELDS = [
    [ :display_id,    'Ticket ID'           ],
    [ :subject,       'Subject'             ],
    [ :description,   'Ticket Description'  ],
    [ :source,        'Source of Ticket'    ]
  ]

  SEARCH_FIELD_OPTIONS = SEARCH_FIELDS.map { |i| [i[1], i[0]] }

  SORT_FIELDS = [
    [ :due_by     ,   'Due by time',     "due_by ASC"  ],
    [ :created_asc,   'Date Created',    "created_at ASC"  ],
    [ :updated_asc,   'Last Modified',   "updated_at ASC"  ],
    [ :priority   ,   'Priority',        "priority DESC"  ],
    [ :status,        'Status',          "status ASC"  ],        
  ]

  SORT_FIELD_OPTIONS = SORT_FIELDS.map { |i| [i[1], i[0]] }
  SORT_SQL_BY_KEY = Hash[*SORT_FIELDS.map { |i| [i[0], i[2]] }.flatten]

  def self.filter(filter, user = nil, scope = nil)
    scope ||= default_scope
    
    conditions = {
      :all          =>    {},
      :spam         =>    { :spam => true, :deleted => false },
      :deleted      =>    { :deleted => true },
      :visible      =>    { :deleted => false, :spam => false },
      :responded_by =>    { :responder_id => (user && user.id) || -1 },
      :monitored_by =>    {}, # See below
      
      :new_and_my_open  => ["status = ? or (responder_id = ? and status = ?)", 
                                      STATUS_KEYS_BY_TOKEN[:new], user.id, STATUS_KEYS_BY_TOKEN[:open]],
      :my_open          => ["responder_id = ? and status = ?", user.id, STATUS_KEYS_BY_TOKEN[:open]],
      :my_resolved      => ["responder_id = ? and status = ?", user.id, STATUS_KEYS_BY_TOKEN[:resolved]],
      :my_closed        => ["responder_id = ? and status = ?", user.id, STATUS_KEYS_BY_TOKEN[:closed]],
      :my_due_today     => ["responder_id = ? and due_by <= ? and status not in (?, ?)", user.id, 
                                      Time.now.end_of_day.to_s(:db), STATUS_KEYS_BY_TOKEN[:resolved], 
                                      STATUS_KEYS_BY_TOKEN[:closed]],
      :my_overdue       => ["responder_id = ? and due_by <= ? and status not in (?, ?)", user.id, 
                                      Time.now.to_s(:db), STATUS_KEYS_BY_TOKEN[:resolved], 
                                      STATUS_KEYS_BY_TOKEN[:closed]],
      :my_on_hold       => ["responder_id = ? and status = ?", user.id, STATUS_KEYS_BY_TOKEN[:pending]],
      :my_all           => ["responder_id = ?", user.id],
      
      :new              => ["status = ?", STATUS_KEYS_BY_TOKEN[:new]],
      :open             => ["status = ?", STATUS_KEYS_BY_TOKEN[:open]],
      :new_and_open     => ["status in (?, ?)", STATUS_KEYS_BY_TOKEN[:new], STATUS_KEYS_BY_TOKEN[:open]],
      :resolved         => ["status = ?", STATUS_KEYS_BY_TOKEN[:resolved]],
      :closed           => ["status = ?", STATUS_KEYS_BY_TOKEN[:closed]],
      :due_today        => ["due_by <= ? and status not in (?, ?)", Time.now.end_of_day.to_s(:db), 
                                      STATUS_KEYS_BY_TOKEN[:resolved], STATUS_KEYS_BY_TOKEN[:closed]],
      :overdue          => ["due_by <= ? and status not in (?, ?)", Time.now.to_s(:db), 
                                      STATUS_KEYS_BY_TOKEN[:resolved], STATUS_KEYS_BY_TOKEN[:closed]],
      :on_hold          => ["status = ?", STATUS_KEYS_BY_TOKEN[:pending]]
    }
        
    if user && filter == :monitored_by
      to_ret = user.subscribed_tickets.scoped(:conditions => {:spam => false, :deleted => false})
    else
      to_ret = scope.scoped(:conditions => conditions[filter])
    end
    
    ADDITIONAL_FILTERS[filter].each do |af|
      to_ret = to_ret.scoped(:conditions => conditions[af])
    end unless ADDITIONAL_FILTERS[filter].nil?

    to_ret
  end

  def default_scope
    eval "Helpdesk::Ticket"
  end

  def self.search(scope, field, value)
    return scope unless (field && value)

    loose_match = ["#{field} like ?", "%#{value}%"]
    exact_match = {field => value}

    conditions = case field.to_sym
      when :subject      :  loose_match
      when :display_id   :  exact_match
      when :description  :  loose_match
      when :status       :  exact_match
      when :urgent       :  exact_match
      when :source       :  exact_match
    end

    # Protect us from SQL injection in the 'field' param
    return scope unless conditions

    scope.scoped(:conditions => conditions)
  end

end

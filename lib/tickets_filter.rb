module TicketsFilter
  include TicketConstants
  
  DEFAULT_FILTER = [:new_and_my_open]

  SELECTORS = [
    [[:new_and_my_open],  "New & My Open Tickets"  ],
    [[:my_open],          "My Open Tickets"  ],
    [[:my_resolved],      "My Resolved Tickets" ],
    [[:my_closed],        "My Closed Tickets"  ],
    [[:my_due_today],     "My Tickets Due Today"  ],
    [[:my_overdue],       "My Overdue Tickets"  ],
    [[:my_on_hold],       "My Tickets On Hold"  ],
    [[:monitored_by],     "Tickets I'm Monitoring"  ],
    [[:my_all],           "All My Tickets"  ],
    
    [[:new],              "New Tickets"  ],
    [[:open],             "Open Tickets"  ],
    [[:new_and_open],     "New & Open Tickets"  ],
    [[:resolved],         "Resolved Tickets"  ],
    [[:closed],           "Closed Tickets"  ],
    [[:due_today],        "Tickets Due Today"  ],
    [[:overdue],          "Overdue Tickets"  ],
    [[:on_hold],          "Tickets On Hold"  ],
    [[:all],              "All Tickets "  ],
    
    [[:spam],             "Spam"  ],
    [[:deleted],          "Trash"  ]
  ]
  
  SELECTOR_NAMES = Hash[*SELECTORS.inject([]){ |a, v| a += [v[0], v[1]] }]
  
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

  def self.filter(filters, user = nil, scope = nil)
    conditions = {
      :all          =>    {},
      :unassigned   =>    {:responder_id => nil, :deleted => false, :spam => false},
      :spam         =>    {:spam => true},
      :deleted      =>    {:deleted => true},
      :visible      =>    {:deleted => false, :spam => false},
      :responded_by =>    {:responder_id => (user && user.id) || -1, :deleted => false, :spam => false},
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

    filters.inject(scope || default_scope) do |scope, f|
      f = f.to_sym

      if user && f == :monitored_by
        user.subscribed_tickets.scoped(:conditions => {:spam => false, :deleted => false})
      else
        scope.scoped(:conditions => conditions[f])
      end
    end

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

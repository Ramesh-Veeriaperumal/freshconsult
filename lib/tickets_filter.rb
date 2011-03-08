module TicketsFilter
  include TicketConstants
  
  DEFAULT_FILTER = :new_and_my_open

  SELECTORS = [
    [:new_and_my_open,  "New & My Open Tickets", [:visible]  ],
    [:my_open,          "My Open Tickets", [:visible, :responded_by, :open]  ],
    [:my_resolved,      "My Resolved Tickets", [:visible, :responded_by, :resolved] ],
    [:my_closed,        "My Closed Tickets", [:visible, :responded_by, :closed]  ],
    [:my_due_today,     "My Tickets Due Today", [:visible, :responded_by, :due_today]  ],
    [:my_overdue,       "My Overdue Tickets", [:visible, :responded_by, :overdue]  ],
    [:my_on_hold,       "My Tickets On Hold", [:visible, :responded_by, :on_hold]  ],
    [:monitored_by,     "Tickets I'm Monitoring", [:visible]  ],
    [:my_all,           "All My Tickets", [:visible, :responded_by]  ],
    
    [:new,              "New Tickets", [:visible]  ],
    [:open,             "Open Tickets", [:visible]  ],
    #[:new_and_open,     "New & Open Tickets", [:visible]  ],
    [:resolved,         "Resolved Tickets", [:visible]  ],
    [:closed,           "Closed Tickets", [:visible]  ],
    [:due_today,        "Tickets Due Today", [:visible]  ],
    [:overdue,          "Overdue Tickets", [:visible]  ],
    [:on_hold,          "Tickets On Hold", [:visible]  ],
    [:all,              "All Tickets ", [:visible]  ],
    
    [:spam,             "Spam"  ],
    [:deleted,          "Trash"  ],
    [:tags  ,           "Tags by Ticket" ]
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
    [ :priority   ,   'Priority',        "priority ASC"  ],
    [ :status,        'Status',          "status ASC"  ],        
  ]

  SORT_FIELD_OPTIONS = SORT_FIELDS.map { |i| [i[1], i[0]] }
  SORT_SQL_BY_KEY = Hash[*SORT_FIELDS.map { |i| [i[0], i[2]] }.flatten]

  def self.filter(filter, user = nil, scope = nil)
    to_ret = (scope ||= default_scope)
    
    conditions = load_conditions(user)

    if user && filter == :monitored_by
      to_ret = user.subscribed_tickets.scoped(:conditions => {:spam => false, :deleted => false})
    else
      to_ret = to_ret.scoped(:conditions => conditions[filter]) unless conditions[filter].nil?
    end
    
    ADDITIONAL_FILTERS[filter].each do |af|
      to_ret = to_ret.scoped(:conditions => conditions[af])
    end unless ADDITIONAL_FILTERS[filter].nil?

    to_ret
  end

  def self.default_scope
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
  
  protected
    def self.load_conditions(user)
      {
        :spam         =>    { :spam => true, :deleted => false },
        :deleted      =>    { :deleted => true },
        :visible      =>    { :deleted => false, :spam => false },
        :responded_by =>    { :responder_id => (user && user.id) || -1 },
        
        :new_and_my_open  => ["status = ? and (responder_id is NULL or responder_id = ?)", 
                                        STATUS_KEYS_BY_TOKEN[:open], user.id],
        
        :new              => ["status = ? and responder_id is NULL", STATUS_KEYS_BY_TOKEN[:open]],
        :open             => ["status = ?", STATUS_KEYS_BY_TOKEN[:open]],
        #:new_and_open     => ["status in (?, ?)", STATUS_KEYS_BY_TOKEN[:new], STATUS_KEYS_BY_TOKEN[:open]],
        :resolved         => ["status = ?", STATUS_KEYS_BY_TOKEN[:resolved]],
        :closed           => ["status = ?", STATUS_KEYS_BY_TOKEN[:closed]],
        :due_today        => ["due_by >= ? and due_by <= ? and status not in (?, ?)", Time.zone.now.beginning_of_day.to_s(:db), 
                                 Time.zone.now.end_of_day.to_s(:db), STATUS_KEYS_BY_TOKEN[:resolved], STATUS_KEYS_BY_TOKEN[:closed]],
        :overdue          => ["due_by <= ? and status not in (?, ?)", Time.zone.now.to_s(:db), 
                                        STATUS_KEYS_BY_TOKEN[:resolved], STATUS_KEYS_BY_TOKEN[:closed]],
        :on_hold          => ["status = ?", STATUS_KEYS_BY_TOKEN[:pending]]
      }
    end

end

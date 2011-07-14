module TicketsFilter
  include TicketConstants
  
  DEFAULT_FILTER = :new_and_my_open

  SELECTORS = [
    [:new_and_my_open,  I18n.t('helpdesk.tickets.views.new_and_my_open'), [:visible]  ],
    [:my_open,          I18n.t('helpdesk.tickets.views.my_open'), [:visible, :responded_by, :open]  ],
    [:my_resolved,      I18n.t('helpdesk.tickets.views.my_resolved'), [:visible, :responded_by, :resolved] ],
    [:my_closed,        I18n.t('helpdesk.tickets.views.my_closed'), [:visible, :responded_by, :closed]  ],
    [:my_due_today,     I18n.t('helpdesk.tickets.views.my_due_today'), [:visible, :responded_by, :due_today]  ],
    [:my_overdue,       I18n.t('helpdesk.tickets.views.my_overdue'), [:visible, :responded_by, :overdue]  ],
    [:my_on_hold,       I18n.t('helpdesk.tickets.views.my_on_hold'), [:visible, :responded_by, :on_hold]  ],
    [:monitored_by,     I18n.t('helpdesk.tickets.views.monitored_by'), [:visible]  ],
    [:my_all,           I18n.t('helpdesk.tickets.views.my_all'), [:visible, :responded_by]  ],
    
    [:new,              I18n.t('helpdesk.tickets.views.new'), [:visible]  ],
    [:open,             I18n.t('helpdesk.tickets.views.open'), [:visible]  ],
    #[:new_and_open,     "New & Open Tickets", [:visible]  ],
    [:resolved,         I18n.t('helpdesk.tickets.views.resolved'), [:visible]  ],
    [:closed,           I18n.t('helpdesk.tickets.views.closed'), [:visible]  ],
    [:due_today,        I18n.t('helpdesk.tickets.views.due_today'), [:visible]  ],
    [:overdue,          I18n.t('helpdesk.tickets.views.overdue'), [:visible]  ],
    [:on_hold,          I18n.t('helpdesk.tickets.views.on_hold'), [:visible]  ],
    [:all,              I18n.t('helpdesk.tickets.views.all'), [:visible]  ],
    
    [:spam,             I18n.t('helpdesk.tickets.views.spam')  ],
    [:deleted,          I18n.t('helpdesk.tickets.views.trash')  ],
    [:tags  ,           I18n.t('helpdesk.tickets.views.tags') ]
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

  DEFAULT_SORT 			= :due_by
  DEFAULT_SORT_ORDER 	= :ASC
	
  SORT_FIELDS = [
    [ :due_by     , I18n.t("tickets_filter.sort_fields.due_by")        ],
    [ :created_at , I18n.t("tickets_filter.sort_fields.date_created")  ],
    [ :updated_at , I18n.t("tickets_filter.sort_fields.last_modified") ],
    [ :priority   , I18n.t("tickets_filter.sort_fields.priority")      ],
    [ :status     , I18n.t("tickets_filter.sort_fields.status")        ]
  ]

  SORT_FIELD_OPTIONS = SORT_FIELDS.map { |i| [i[1], i[0]] }
  SORT_SQL_BY_KEY    = Hash[*SORT_FIELDS.map { |i| [i[0], i[0]] }.flatten]

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

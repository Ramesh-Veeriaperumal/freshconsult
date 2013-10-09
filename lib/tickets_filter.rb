module TicketsFilter
  include TicketConstants
  include Helpdesk::Ticketfields::TicketStatus
  
  DEFAULT_FILTER = "new_and_my_open"

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
    
    [ :my_groups_open,    I18n.t('helpdesk.tickets.views.my_groups_open'), [:visible, :my_groups, :open] ],
    [ :my_groups_new,     I18n.t('helpdesk.tickets.views.my_groups_new'), [:visible, :my_groups, :new] ],
    [ :my_groups_pending, I18n.t('helpdesk.tickets.views.my_groups_pending'), [:visible, :my_groups, :on_hold] ],
    [ :my_groups_all,     I18n.t('helpdesk.tickets.views.my_groups_all'), [:visible, :my_groups] ],
    
    [:new,              I18n.t('helpdesk.tickets.views.new'), [:visible]  ],
    [:open,             I18n.t('helpdesk.tickets.views.open'), [:visible]  ],
    #[:new_and_open,     "New & Open Tickets", [:visible]  ],
    [:resolved,         I18n.t('helpdesk.tickets.views.resolved'), [:visible]  ],
    [:closed,           I18n.t('helpdesk.tickets.views.closed'), [:visible]  ],
    [:due_today,        I18n.t('helpdesk.tickets.views.due_today'), [:visible]  ],
    [:overdue,          I18n.t('helpdesk.tickets.views.overdue'), [:visible]  ],
    [:on_hold,          I18n.t('helpdesk.tickets.views.on_hold'), [:visible]  ],
    [:all,              I18n.t('helpdesk.tickets.views.all_tickets'), [:visible]  ],
    
    [:spam,             I18n.t('helpdesk.tickets.views.spam')  ],
    [:deleted,          I18n.t('helpdesk.tickets.views.trash')  ],
    [:tags  ,           I18n.t('helpdesk.tickets.views.tags') ],
    [:twitter  ,        I18n.t('helpdesk.tickets.views.tickets_twitter')],
    
    
  ]

  JOINS = {
    :on_hold => "STRAIGHT_JOIN helpdesk_ticket_statuses ON 
          helpdesk_tickets.account_id = helpdesk_ticket_statuses.account_id AND 
          helpdesk_tickets.status = helpdesk_ticket_statuses.status_id",
    :overdue => "STRAIGHT_JOIN helpdesk_ticket_statuses ON 
          helpdesk_tickets.account_id = helpdesk_ticket_statuses.account_id AND 
          helpdesk_tickets.status = helpdesk_ticket_statuses.status_id",
    :due_today => "STRAIGHT_JOIN helpdesk_ticket_statuses ON 
          helpdesk_tickets.account_id = helpdesk_ticket_statuses.account_id AND 
          helpdesk_tickets.status = helpdesk_ticket_statuses.status_id",
  }
  
  SELECTOR_NAMES = Hash[*SELECTORS.inject([]){ |a, v| a += [v[0], v[1]] }]
  ADDITIONAL_FILTERS = Hash[*SELECTORS.inject([]){ |a, v| a += [v[0], v[2]] }]
  
  CUSTOMER_SELECTORS = [ [:all,              I18n.t('helpdesk.tickets.views.all'), [:visible]  ],
                         [:open_or_pending, I18n.t('helpdesk.tickets.views.open_or_pending') ],
                         [:resolved_or_closed,  I18n.t('helpdesk.tickets.views.resolved_or_closed')]
                       ]
  CUSTOMER_SELECTOR_NAMES = Hash[*CUSTOMER_SELECTORS.inject([]){ |a, v| a += [v[0], v[1]] }]
  CUSTOMER_ADDITIONAL_FILTERS = Hash[*CUSTOMER_SELECTORS.inject([]){ |a, v| a += [v[0], v[2]] }]
  
  SEARCH_FIELDS = [
    [ :display_id,    'Ticket ID'           ],
    [ :subject,       'Subject'             ],
    [ :description,   'Ticket Description'  ],
    [ :source,        'Source of Ticket'    ]
  ]

  SEARCH_FIELD_OPTIONS = SEARCH_FIELDS.map { |i| [i[1], i[0]] }

  DEFAULT_SORT        = :created_at
  DEFAULT_SORT_ORDER  = :desc
  DEFAULT_PORTAL_SORT = :created_at
  DEFAULT_PORTAL_SORT_ORDER = :desc

  SORT_FIELDS = [
    [ :due_by     , "tickets_filter.sort_fields.due_by"        ],
    [ :created_at , "tickets_filter.sort_fields.date_created"  ],
    [ :updated_at , "tickets_filter.sort_fields.last_modified" ],
    [ :priority   , "tickets_filter.sort_fields.priority"      ],
    [ :status     , "tickets_filter.sort_fields.status"        ]
  ]

  def self.sort_fields_options
    SORT_FIELDS.map { |i| [I18n.t(i[1]), i[0]] }
  end

  SORT_FIELD_OPTIONS = SORT_FIELDS.map { |i| [i[1], i[0]] }
  SORT_SQL_BY_KEY    = Hash[*SORT_FIELDS.map { |i| [i[0], i[0]] }.flatten]

  SORT_ORDER_FIELDS = [
    [ :asc     , "tickets_filter.sort_fields.asc"   ],
    [ :desc    , "tickets_filter.sort_fields.desc"  ]
  ]

  def self.sort_order_fields_options
    SORT_ORDER_FIELDS.map { |i| [I18n.t(i[1]), i[0]] }
  end
  SORT_ORDER_FIELDS_OPTIONS = SORT_ORDER_FIELDS.map { |i| [i[1], i[0]] }
  SORT_ORDER_FIELDS_BY_KEY  = Hash[*SORT_ORDER_FIELDS.map { |i| [i[0], i[0]] }.flatten]

  def self.filter(filter, user = nil, scope = nil)
    to_ret = (scope ||= default_scope)
    
    conditions = load_conditions(user,filter)

    if user && filter == :monitored_by
      to_ret = user.subscribed_tickets.scoped(:conditions => {:spam => false, :deleted => false})
    else
      to_ret = to_ret.scoped(:conditions => conditions[filter]) unless conditions[filter].nil?
    end
    
    ADDITIONAL_FILTERS[filter].each do |af|
      to_ret = to_ret.scoped(:conditions => conditions[af])
    end unless ADDITIONAL_FILTERS[filter].nil?
    join = JOINS[filter]
    to_ret = to_ret.scoped(:joins => join) if join
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
      when :subject
        loose_match
      when :display_id
        exact_match
      when :description
        loose_match
      when :status
        exact_match
      when :urgent
        exact_match
      when :source
        exact_match
    end

    # Protect us from SQL injection in the 'field' param
    return scope unless conditions

    scope.scoped(:conditions => conditions)
  end
  
  protected
    def self.load_conditions(user,filter)
      donot_stop_sla_status_query = "select status_id from helpdesk_ticket_statuses where 
                  (stop_sla_timer is false and account_id = #{user.account.id} and deleted is false)"
      onhold_statuses_query = "select status_id from helpdesk_ticket_statuses where 
      (stop_sla_timer is true and account_id = #{user.account.id} and deleted is false and status_id not in (#{RESOLVED},#{CLOSED}))"
      group_ids = user.agent_groups.find(:all, :select => 'group_id').map(&:group_id) if filter.nil? || filter.eql?(:my_groups)
      group_ids = [-1] if group_ids.nil? || group_ids.empty? #The whole group thing is a hack till new views come..
      
      {
        :spam         =>    { :spam => true, :deleted => false },
        :deleted      =>    { :deleted => true },
        :visible      =>    { :deleted => false, :spam => false },
        :responded_by =>    { :responder_id => (user && user.id) || -1 },
        :my_groups    =>    { :group_id => group_ids },
        
        :new_and_my_open  => ["status = ? and (responder_id is NULL or responder_id = ?)", OPEN, user.id],
        
        :new              => ["status = ? and responder_id is NULL", OPEN],
        :open             => ["status = ?", OPEN],
        #:new_and_open     => ["status in (?, ?)", STATUS_KEYS_BY_TOKEN[:new], STATUS_KEYS_BY_TOKEN[:open]],
        :resolved         => ["status = ?", RESOLVED],
        :closed           => ["status = ?", CLOSED],
        # :due_today        => ["due_by >= ? and due_by <= ? and status in (#{donot_stop_sla_status_query})", Time.zone.now.beginning_of_day.to_s(:db), 
        #                          Time.zone.now.end_of_day.to_s(:db)],
        :due_today        => ["due_by >= ? and due_by <= ? 
                                AND helpdesk_ticket_statuses.stop_sla_timer IS FALSE 
                                AND helpdesk_ticket_statuses.deleted IS FALSE", 
                                Time.zone.now.beginning_of_day.to_s(:db), Time.zone.now.end_of_day.to_s(:db)],
        # :overdue          => ["due_by <= ? and status in (#{donot_stop_sla_status_query})", Time.zone.now.to_s(:db)],
        :overdue          => ["due_by <= ? AND helpdesk_ticket_statuses.stop_sla_timer IS FALSE 
                                AND helpdesk_ticket_statuses.deleted IS FALSE", Time.zone.now.to_s(:db)],
        :pending          => ["status = ?", PENDING],
        # :on_hold          => ["status in (#{onhold_statuses_query})"],
        :on_hold          => ["helpdesk_ticket_statuses.stop_sla_timer IS TRUE 
                                AND helpdesk_ticket_statuses.deleted IS FALSE
                                and helpdesk_ticket_statuses.status_id NOT IN 
                                (#{RESOLVED},#{CLOSED})"],
        :twitter          => ["source = ?", SOURCE_KEYS_BY_TOKEN[:twitter]],
        :open_or_pending  => ["status not in (?, ?) and helpdesk_tickets.deleted=?" , RESOLVED, CLOSED , false],
        :resolved_or_closed  => ["status in (?, ?) and helpdesk_tickets.deleted=?" , RESOLVED, CLOSED,false]
      }
    end
end

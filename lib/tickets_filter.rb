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
    [:raised_by_me,     I18n.t('helpdesk.tickets.views.raised_by_me'), [:visible] ],
    [:shared_by_me,     I18n.t('helpdesk.tickets.views.shared_by_me'), [:visible] ],
    [:shared_with_me,   I18n.t('helpdesk.tickets.views.shared_with_me'), [:visible] ],
    [:my_all,           I18n.t('helpdesk.tickets.views.my_all'), [:visible, :responded_by]  ],
    [:article_feedback, I18n.t('helpdesk.tickets.views.article_feedback'), [:visible]  ],
    [:my_article_feedback, I18n.t('helpdesk.tickets.views.my_article_feedback'), [:visible]  ],
    
    [ :my_groups_open,    I18n.t('helpdesk.tickets.views.my_groups_open'), [:visible, :my_groups, :open] ],
    [ :my_groups_new,     I18n.t('helpdesk.tickets.views.my_groups_new'), [:visible, :my_groups, :new] ],
    [ :my_groups_pending, I18n.t('helpdesk.tickets.views.my_groups_pending'), [:visible, :my_groups, :on_hold] ],
    [ :my_groups_all,     I18n.t('helpdesk.tickets.views.my_groups_all'), [:visible, :my_groups] ],
    
    [:untitled_view,    I18n.t('tickets_filter.unsaved_view'), [:visible] ],
    [:new,              I18n.t('helpdesk.tickets.views.new'), [:visible]  ],
    [:open,             I18n.t('helpdesk.tickets.views.open'), [:visible]  ],
    #[:new_and_open,     "New & Open Tickets", [:visible]  ],
    [:resolved,         I18n.t('helpdesk.tickets.views.resolved'), [:visible]  ],
    [:closed,           I18n.t('helpdesk.tickets.views.closed'), [:visible]  ],
    [:due_today,        I18n.t('helpdesk.tickets.views.due_today'), [:visible]  ],
    [:overdue,          I18n.t('helpdesk.tickets.views.overdue'), [:visible]  ],
    [:on_hold,          I18n.t('helpdesk.tickets.views.on_hold'), [:visible]  ],
    [:all,              I18n.t('helpdesk.tickets.views.all_tickets'), [:visible]  ],
    
    [:unresolved,       I18n.t('helpdesk.tickets.views.unresolved'), [:visible]  ],
    [:spam,             I18n.t('helpdesk.tickets.views.spam')  ],
    [:deleted,          I18n.t('helpdesk.tickets.views.trash')  ],
    [:tags  ,           I18n.t('helpdesk.tickets.views.tags') ],
    [:twitter  ,        I18n.t('helpdesk.tickets.views.tickets_twitter')],
    [:mobihelp  ,        I18n.t('helpdesk.tickets.views.mobihelp')],
    
    
  ]

  JOINS = {
    :on_hold => "INNER JOIN helpdesk_ticket_statuses ON 
          helpdesk_tickets.account_id = helpdesk_ticket_statuses.account_id AND 
          helpdesk_tickets.status = helpdesk_ticket_statuses.status_id",
    :overdue => "INNER JOIN helpdesk_ticket_statuses ON 
          helpdesk_tickets.account_id = helpdesk_ticket_statuses.account_id AND 
          helpdesk_tickets.status = helpdesk_ticket_statuses.status_id",
    :due_today => "INNER JOIN helpdesk_ticket_statuses ON 
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

  DEFAULT_AGENT_MODE  = 0
  DEFAULT_GROUP_MODE  = 0
  DEFAULT_SORT        = :created_at
  DEFAULT_SORT_ORDER  = :desc
  DEFAULT_PORTAL_SORT = :created_at
  DEFAULT_PORTAL_SORT_ORDER = :desc

  SORT_FIELDS = [
    [ :created_at , "tickets_filter.sort_fields.date_created"  ],
    [ :updated_at , "tickets_filter.sort_fields.last_modified" ],
    [ :priority   , "tickets_filter.sort_fields.priority"      ],
    [ :status     , "tickets_filter.sort_fields.status"        ]
  ]

  COLLAB_SORT_FIELDS = [
    [:recently_active , "tickets_filter.sort_fields.recently_active"]
  ]

  def self.collab_sort_field
    sort_fields = COLLAB_SORT_FIELDS.clone
    sort_fields.map { |i| [I18n.t(i[1]), i[0]] }  
  end

  AGENT_SORT_FIELDS = [
    [ :responder_id , "filter_options.responder_id" , FILTER_MODES[:primary]],
    [ "helpdesk_schema_less_tickets.long_tc04" , "filter_options.internal_agent" , FILTER_MODES[:internal]],
    [ :any_agent_id , "filter_options.any_agent" , FILTER_MODES[:any]]
  ]

  GROUP_SORT_FIELDS = [
    [ :group_id , "filter_options.group_id" , FILTER_MODES[:primary]],
    [ "helpdesk_schema_less_tickets.long_tc03" , "filter_options.internal_group" , FILTER_MODES[:internal]],
    [ :any_group_id , "filter_options.any_group" , FILTER_MODES[:any]]
  ]

  def self.sort_fields_options
    sort_fields = SORT_FIELDS.clone
    if Account.current && Account.current.features_included?(:sort_by_customer_response)
      sort_fields << [ :requester_responded_at, "tickets_filter.sort_fields.requester_responded_at"]
      sort_fields << [ :agent_responded_at, "tickets_filter.sort_fields.agent_responded_at"]
    end

    sort_fields.insert(0, [ :due_by, "tickets_filter.sort_fields.due_by"]) if Account.current && Account.current.sla_management_enabled?
    
    sort_fields.map { |i| [I18n.t(i[1]), i[0]] }
  end

  def self.shared_agent_sort_fields_options
    sort_fields = AGENT_SORT_FIELDS.clone
    sort_fields.map { |i| [I18n.t(i[1]), i[0], i[2]] }
  end

  def self.shared_group_sort_fields_options
    sort_fields = GROUP_SORT_FIELDS.clone
    sort_fields.map { |i| [I18n.t(i[1]), i[0], i[2]] }
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

  DEFAULT_VISIBLE_FILTERS = %w( new_and_my_open unresolved all_tickets raised_by_me monitored_by spam deleted )
  SHARED_OWNERSHIP_DEFAULT_VISIBLE_FILTERS = %w( new_and_my_open shared_by_me shared_with_me unresolved all_tickets raised_by_me monitored_by spam deleted )
  DEFAULT_VISIBLE_FILTERS_WITH_ARCHIVE = %w( new_and_my_open unresolved all_tickets raised_by_me monitored_by archived spam deleted )
  SHARED_OWNERSHIP_DEFAULT_VISIBLE_FILTERS_WITH_ARCHIVE = %w( new_and_my_open shared_by_me shared_with_me unresolved all_tickets raised_by_me monitored_by archived spam deleted )
  DEFAULT_VISIBLE_FILTERS_WITH_COLLABORATION = %w( ongoing_collab new_and_my_open unresolved all_tickets raised_by_me monitored_by spam deleted )
  SHARED_OWNERSHIP_DEFAULT_VISIBLE_FILTERS_WITH_COLLABORATION = %w( ongoing_collab new_and_my_open shared_by_me shared_with_me unresolved all_tickets raised_by_me monitored_by spam deleted )
  DEFAULT_VISIBLE_FILTERS_WITH_ARCHIVE_AND_COLLABORATION = %w( ongoing_collab new_and_my_open unresolved all_tickets raised_by_me monitored_by archived spam deleted )
  SHARED_OWNERSHIP_DEFAULT_VISIBLE_FILTERS_WITH_ARCHIVE_AND_COLLABORATION = %w( ongoing_collab new_and_my_open shared_by_me shared_with_me unresolved all_tickets raised_by_me monitored_by archived spam deleted )

  def self.mobile_sort_fields_options
    sort_fields = self.sort_fields_options

    sort_fields.map { |i| {
        :id       =>  i[1], 
        :name     =>  i[0], 
      } }
  end

  def self.mobile_sort_order_fields_options
    sort_order_fields = self.sort_order_fields_options
    sort_order_fields.map { |i| {
        :id       =>  i[1], 
        :name     =>  i[0], 
      } }
  end

  def self.default_views
    @shared_ownership_on = Account.current.features?(:shared_ownership)
    @collaboration_on = Account.current.features?(:collaboration)

    filters = if Account.current && Account.current.features_included?(:archive_tickets)
      @collaboration_on ? (@shared_ownership_on ? SHARED_OWNERSHIP_DEFAULT_VISIBLE_FILTERS_WITH_ARCHIVE_AND_COLLABORATION : DEFAULT_VISIBLE_FILTERS_WITH_ARCHIVE_AND_COLLABORATION) : ( @shared_ownership_on ? SHARED_OWNERSHIP_DEFAULT_VISIBLE_FILTERS_WITH_ARCHIVE : DEFAULT_VISIBLE_FILTERS_WITH_ARCHIVE)
    elsif @collaboration_on
      @shared_ownership_on ? SHARED_OWNERSHIP_DEFAULT_VISIBLE_FILTERS_WITH_COLLABORATION : DEFAULT_VISIBLE_FILTERS_WITH_COLLABORATION
    else
      @shared_ownership_on ? SHARED_OWNERSHIP_DEFAULT_VISIBLE_FILTERS : DEFAULT_VISIBLE_FILTERS
    end
    filters.map { |i| {
        :id       =>  i, 
        :name     =>  I18n.t("helpdesk.tickets.views.#{i}"), 
        :default  =>  true 
      } }
  end

  def self.filter(filter, user = nil, scope = nil)
    to_ret = (scope ||= default_scope)
    
    conditions = load_conditions(user,filter)
    if user && filter == :monitored_by
      to_ret = user.subscribed_tickets.where({:spam => false, :deleted => false})
    else
      to_ret = to_ret.where(conditions[filter]) unless conditions[filter].nil?
    end
    
    ADDITIONAL_FILTERS[filter].each do |af|
      to_ret = to_ret.where(conditions[af])
    end unless ADDITIONAL_FILTERS[filter].nil?
    join = JOINS[filter]
    to_ret = to_ret.joins(join) if join
    to_ret
  end

  ### ES Count query related hacks : START ###

  ### Hack for dashboard/API summary count fetching from ES
  def self.es_filter_count(selector, unresolved=false, agent_filter=false)
    custom_filter       = Helpdesk::Filters::CustomTicketFilter.new
    action_hash         = custom_filter.default_filter(selector.to_s) || []
    negative_conditions = (unresolved ? [{ "condition" => "status", "operator" => "is_not", "value" => "#{RESOLVED},#{CLOSED}" }] : [])
    
    action_hash.push({ "condition" => "responder_id", "operator" => "is_in", "value" => "0" }) if agent_filter

    Search::Filters::Docs.new(action_hash, negative_conditions).count(Helpdesk::Ticket)
  end

  ### ES Count query related hacks : END ###

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

    scope.where(conditions)
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
        :mobihelp          => ["source = ?", TicketConstants::SOURCE_KEYS_BY_TOKEN[:mobihelp]],
        :open_or_pending  => ["status not in (?, ?) and helpdesk_tickets.deleted=? and spam=?" , RESOLVED, CLOSED , false, false],
        :resolved_or_closed  => ["status in (?, ?) and helpdesk_tickets.deleted=?" , RESOLVED, CLOSED,false]
      }
    end
end

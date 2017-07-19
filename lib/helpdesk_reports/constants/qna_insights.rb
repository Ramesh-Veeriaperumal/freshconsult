module HelpdeskReports::Constants::QnaInsights
  include HelpdeskReports::Constants

  INCREASE_BAD_METRICS = ['AVG_RESOLUTION_TIME','AVG_FIRST_RESPONSE_TIME', 'AVG_RESPONSE_TIME','RECEIVED_TICKETS','REOPENED_TICKETS','UNRESOLVED_TICKETS', 'AVG_FIRST_ASSIGN_TIME' ]

  RESOLUTION_SLA='RESOLUTION_SLA'

  RESPONSE_SLA='RESPONSE_SLA'

  GROUP_COMPARE_METRIC ='GROUP_COMPARE_METRIC'

  QUERY_RESPONSE_TYPES = {
    avg: 'Avg',
    count: 'Count',
    percentage: 'Percentage'
  }.freeze

  QNA_SUFFIX = '_QNA'

  DATE_FORMATS_TYPES = {
    f1: '%d %b,%Y',
    f2: '%F',
    f3: '%d %b, %Y',
    f4: '%F %T',
    f5: '%-m',
    f6: '%b, %Y'
  }.freeze

  VARIANCE_STATUS = {
    positive: 'positive',
    negative: 'negative',
    neutral: 'neutral'
  }.freeze

  VARIANCE_DIRECTION = {
    down: 0,
    up: 1,
    level: 2
  }.freeze

  REPORT_TYPE = {
    qna:  'qna',
    insight: 'insight'
  }.freeze

  QNA_TYPE = {
    what: '1',
    how_many:'2',
    which_customer:'3',
    which_agent:'4',
    which_group:'5'
  }.freeze

  QNA_GROUP_BY = {
    '3'=>'company_id',
    '4'=>'agent_id',
    '5'=>'group_id'
  }.freeze

  DATE_RANGE = {
    today: 'today',
    yesterday: 'yesterday',
    last_week: 'last_week',
    last_month: 'last_month'
  }.freeze

  INSIGHTS_METRIC_TYPE = {
    simple: 1,
    agent_compare: 2,
    group_compare: 3
  }.freeze

  UNRESOLVED_TICKETS = 'UNRESOLVED_TICKETS'

  TIME_TREND_CONDITIONS = {
    day: ['doy','y'],
    week: ['doy','w','y'],
    month: ['w','mon','y']
  }.freeze

  INSIGHTS_WIDGETS_CONFIG_DEFAULT = {
        d0:{
          metric:"RECEIVED_TICKETS",
          metric_type:"ticket",
          widget_type:INSIGHTS_METRIC_TYPE[:simple]
        },
        d1:{
          metric:"RESOLVED_TICKETS",
          metric_type:"ticket",
          widget_type:INSIGHTS_METRIC_TYPE[:simple]
        },
        d2:{
          metric:"UNRESOLVED_TICKETS",
          category:"ticket",
          widget_type:INSIGHTS_METRIC_TYPE[:simple]
        },
        d3:{
          metric:"REOPENED_TICKETS",
          category:"ticket",
          widget_type:INSIGHTS_METRIC_TYPE[:simple]
        },
        d4:{
          metric:"AVG_FIRST_RESPONSE_TIME",
          category:"ticket",
          widget_type:INSIGHTS_METRIC_TYPE[:simple]
        },
        d5:{
          metric:"AVG_RESPONSE_TIME",
          category:"ticket",
          widget_type:INSIGHTS_METRIC_TYPE[:simple]
        },
        d6:{
          metric:"AVG_RESOLUTION_TIME",
          category:"ticket",
          widget_type:INSIGHTS_METRIC_TYPE[:simple]
        },
        d7:{
          metric:"AVG_FIRST_ASSIGN_TIME",
          category:"ticket",
          widget_type:INSIGHTS_METRIC_TYPE[:simple]
        },
        d8:{
          metric:"RESPONSE_SLA",
          category:"ticket",
          widget_type:INSIGHTS_METRIC_TYPE[:simple]
        },
        d9:{
          metric:"RESOLUTION_SLA",
          category:"ticket",
          widget_type:INSIGHTS_METRIC_TYPE[:simple]
        },
        d10:{
          metric:"AVG_FIRST_RESPONSE_TIME",
          category:"ticket",
          widget_type:INSIGHTS_METRIC_TYPE[:agent_compare]
        },
        d11:{
          metric:"AVG_FIRST_RESPONSE_TIME",
          category:"ticket",
          widget_type:INSIGHTS_METRIC_TYPE[:group_compare]
        }
      }.freeze

end

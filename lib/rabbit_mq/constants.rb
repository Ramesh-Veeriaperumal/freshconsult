module RabbitMq::Constants
  
  CONNECTION_TIMEOUT = 0.5
  
  CRUD = ["create", "update", "destroy"]
  
  CRUD_COMBINATIONS = [
    [:create,                  [CRUD[0]],                  1],
    [:update,                  [CRUD[1]],                  2],
    [:destroy,                 [CRUD[2]],                  3],
    [:create_and_update,    [CRUD[0], CRUD[1]],            4],
    [:create_and_destroy,   [CRUD[0], CRUD[2]],            5],
    [:update_and_destroy,   [CRUD[1], CRUD[2]],            6],
    [:all,                       CRUD,                     7]
  ]
    
  CRUD_KEYS_BY_TOKEN  = Hash[*CRUD_COMBINATIONS.map {|c| [c[0], c[2]] }.flatten ]
  CRUD_NAMES_BY_KEY   = Hash[*CRUD_COMBINATIONS.map {|c| [c[2], c[1]] }.flatten(1) ]
  CRUD_TOKENS_BY_NAME = Hash[*CRUD_COMBINATIONS.map {|c| [c[0], c[1]] }.flatten(1) ]
  
  
  MODELS = [
    [  'ticket',              CRUD_KEYS_BY_TOKEN[:all],                 'ticket'          ],
    [  'ticket_body',         CRUD_KEYS_BY_TOKEN[:update],              'ticket'          ],
    [  'subscription',        CRUD_KEYS_BY_TOKEN[:create_and_destroy],  'ticket'          ],
    [  'ticket_state',        CRUD_KEYS_BY_TOKEN[:update],              'ticket'          ],
    [  'note',                CRUD_KEYS_BY_TOKEN[:all],                 'note'            ],
    [  'schema_less_note',    CRUD_KEYS_BY_TOKEN[:update],              'note'            ],
    [  'archive_ticket',      CRUD_KEYS_BY_TOKEN[:update],              'archive_ticket'  ],
    [  'archive_note',        CRUD_KEYS_BY_TOKEN[:create],              'archive_note'    ],
    [  'company',             CRUD_KEYS_BY_TOKEN[:all],                 'company'         ],
    [  'company_domain',      CRUD_KEYS_BY_TOKEN[:create_and_destroy],  'company'         ],
    [  'user',                CRUD_KEYS_BY_TOKEN[:all],                 'user'            ],
    [  'user_email',          CRUD_KEYS_BY_TOKEN[:all],                 'user'            ],
    [  'forum_category',      CRUD_KEYS_BY_TOKEN[:create_and_destroy],  'forum_category'  ],
    [  'forum',               CRUD_KEYS_BY_TOKEN[:create_and_destroy],  'forum'           ],
    [  'topic',               CRUD_KEYS_BY_TOKEN[:all],                 'topic'           ],
    [  'post',                CRUD_KEYS_BY_TOKEN[:all],                 'post'            ],
    [  'article',             CRUD_KEYS_BY_TOKEN[:all],                 'article'         ],
    [  'time_sheet',          CRUD_KEYS_BY_TOKEN[:all],                 'time_sheet'      ],
    [  'tag',                 CRUD_KEYS_BY_TOKEN[:all],                 'tag'             ],
    [  'tag_use',             CRUD_KEYS_BY_TOKEN[:create_and_destroy],  'tag_use'         ],
    [  'caller',              CRUD_KEYS_BY_TOKEN[:all],                 'caller'          ],
    [  'account',             CRUD_KEYS_BY_TOKEN[:update_and_destroy],  'account'         ],
    [  'cti_call',            CRUD_KEYS_BY_TOKEN[:create],              'cti_call'        ],
    [  'agent',               CRUD_KEYS_BY_TOKEN[:all],                 'agent'           ],
    [  'va_rule',             CRUD_KEYS_BY_TOKEN[:all],                 'va_rule'         ]
  ]
  
  # If the exchange mapping values ("ticket", "customer") is changed, please make sure that the changes
  # are made in exchanges folder also. Because using the below mapping, 
  # we are dynamically finding the exchange and sending the msg
  MODEL_TO_EXCHANGE_MAPPING = Hash[*MODELS.map { |m| [m[0], m[2]] }.flatten]
  
  MODELS_ACTIONS_TO_PUBLISH = Hash[*MODELS.map { |m| [m[0], m[1]] }.flatten]

  ACTION = { 
    :new             =>  "new_ticket", 
    :status_update   =>  "status_update", 
    :user_assign     =>  "assign_me", 
    :group_assign    =>  "assign_group", 
    :agent_reply     =>  "agent_reply", 
    :customer_reply  =>  "customer_reply"
  }

  CUSTOM_METHODS = {
    "ticket" => ["marketplace_app"]
  }
  

  # Manual publish keys - only for reports
  RMQ_REPORTS_TICKET_KEY         = "*.1.#"
  RMQ_REPORTS_NOTE_KEY           = "*.1.#"
  RMQ_REPORTS_TAG_KEY            = "1"
  RMQ_REPORTS_TAG_USE_KEY        = "1"
  RMQ_REPORTS_ARCHIVE_TICKET_KEY = "1"
  
  # SEARCH KEYS #
  RMQ_SEARCH_TICKET_KEY         = "*.*.1.#"
  RMQ_SEARCH_NOTE_KEY           = "*.*.1.#"
  RMQ_SEARCH_ARCHIVE_TICKET_KEY = "*.1.#"
  RMQ_SEARCH_ARCHIVE_NOTE_KEY   = "1"
  RMQ_SEARCH_ARTICLE_KEY        = "1"
  RMQ_SEARCH_TOPIC_KEY          = "1"
  RMQ_SEARCH_POST_KEY           = "1"
  RMQ_SEARCH_TAG_KEY            = "1"
  RMQ_SEARCH_TAG_USE_KEY        = "1"
  RMQ_SEARCH_COMPANY_KEY        = "1"
  RMQ_SEARCH_USER_KEY           = "1"
  RMQ_SEARCH_CALLER_KEY         = "1"
  RMQ_SEARCH_VA_RULE_KEY        = '1'.freeze

  # Manual publish keys - common for both activities and reports
  RMQ_GENERIC_TICKET_KEY      = '*.1.*.*.1.#'.freeze  # Position 0 -> auto_refresh, 2 -> reports 4 -> search 6-> es count 8-> activities
  RMQ_GENERIC_NOTE_KEY        = "*.1.*.1.#"  # Position 0 -> auto_refresh, 2 -> reports 4 -> activities
  RMQ_GENERIC_ARCHIVE_TKT_KEY = "1.*.*.#"    # Position 0 -> reports

  #when a spam or trash ticket is deleted after 30 days, we are firing a raw query. So deleting from all subscribers by manual publish
  RMQ_CLEANUP_TICKET_KEY      = '*.1.*.1.1.#'.freeze
  
  #used for reports and count cluster tickets alone. 
  RMQ_REPORTS_COUNT_TICKET_KEY = "*.1.*.1.*.#"

  # Manual publish keys - only for activities
  RMQ_ACTIVITIES_TICKET_KEY = "*.*.*.*.1.#"
  RMQ_ACTIVITIES_NOTE_KEY   = "*.*.*.1.#"

  RMQ_COUNT_TICKET_KEY      = "*.*.*.1"
  RMQ_COUNT_TAG_USE_KEY     = "*.1"
  RMQ_TICKET_TAG_USE_KEY    = '1.*.*.*.1.#'.freeze

  AUTO_REFRESH_TICKET_KEYS  = ["id", "display_id", "tag_names", "account_id", "user_id", "responder_id", "group_id", "status",
    "priority", "ticket_type", "source", "requester_id", "due_by", "frDueBy", "first_response_by_bhrs", "created_at", "sl_skill_id",
    "nr_due_by"
  ]

  ACTIVITIES_TICKET_KEYS         = ["id", "account_id", "created_at", "display_id", "updated_at", "parent_id",
                                      "requester_id", "responder_id", "group_id", "outbound_email", "archive"]
  ACTIVITIES_NOTE_KEYS           = ["id", "source","notable_id", "user_id", "private", "incoming", "deleted", "account_id", "created_at", "kind"]
  ACTIVITIES_TOPIC_KEYS          = ["id", "account_id", "user_id", "forum_id", "published"]
  ACTIVITIES_POST_KEYS           = ["id", "account_id", "user_id", "topic_id", "forum_id", "published"]
  ACTIVITIES_FORUM_KEYS          = ["id", "account_id", "name","forum_category_id"]
  ACTIVITIES_FORUM_CATEGORY_KEYS = ["id", "account_id"]
  ACTIVITIES_ARTICLE_KEYS        = ["id", "account_id", "user_id", "folder_id", "status", "modified_by", "modified_at", "language"]
  ACTIVITIES_TIMESHEET_KEYS      = ["id", "account_id", "workable_id", "workable_type", "timer_running"]
  ACTIVITIES_SUBSCRIPTION_KEYS   = ["id", "account_id", "user_id", "ticket_id"]
  ACTIVITIES_ARCHIVE_TICKET_KEYS = ACTIVITIES_TICKET_KEYS

  
  REPORTS_TICKET_KEYS = ["display_id", "id", "account_id", "agent_id", "group_id", 
    "product_id", "company_id", "status", "priority", "source", "requester_id", "ticket_type", 
    "visible", "sla_policy_id", "association_type", "is_escalated", "fr_escalated", "nr_escalated", "resolved_at", 
    "time_to_resolution_in_bhrs", "time_to_resolution_in_chrs", "inbound_count",
    "first_response_by_bhrs", "first_assign_by_bhrs", "created_at", "archive", "actor_type", "actor_id",
    "internal_agent_id", "internal_group_id", 

    # columns stored in reports_hash in schema_less_ticket
    "first_response_id", "first_response_agent_id", "first_response_group_id", "first_assign_agent_id", "first_assign_group_id",
    "agent_reassigned_count", "group_reassigned_count", "reopened_count", "private_note_count", "public_note_count",
    "agent_reply_count", "customer_reply_count", "agent_assigned_flag", "agent_reassigned_flag", "group_assigned_flag", "group_reassigned_flag",
    "internal_agent_assigned_flag", "internal_agent_reassigned_flag", "internal_group_assigned_flag", "internal_group_reassigned_flag",
    "internal_agent_first_assign_in_bhrs", "last_resolved_at"
  ]

  SLA_KEYS = ['fr_due_by', 'nr_due_by', 'sla_response_reminded', 'sla_resolution_reminded', 'nr_reminded', 'escalation_level', 'fr_escalated', 'nr_escalated'].freeze

  IRIS_TICKET_KEYS = REPORTS_TICKET_KEYS + SLA_KEYS
  IRIS_ARCHIVE_TICKET_KEYS = REPORTS_TICKET_KEYS
  
  REPORTS_ARCHIVE_TICKET_KEYS = REPORTS_TICKET_KEYS
  AUTO_REFRESH_NOTE_KEYS      = ["kind", "private"]
  REPORTS_NOTE_KEYS           = ["id", "source", "user_id", "agent", "category", "private", "incoming", "deleted", "account_id", "created_at", "archive", "actor_type"]
  IRIS_NOTE_KEYS = REPORTS_NOTE_KEYS + ["imported"]
  
  MANUAL_PUBLISH_SUBCRIBERS   = ["reports", "activities", "count"]
  CTI_CALL_KEYS = ["id", "call_sid", "options", "account_id", "responder_id", "requester_id"]
  
  MARKETPLACE_APP_TICKET_KEYS = ["id", "display_id", "subject", "account_id", "user_id", "responder_id", "group_id", "status",
    "priority", "ticket_type", "source", "requester_id", "due_by", "created_at", "is_escalated", "fr_escalated", "nr_escalated", "company_id", "tag_names",
    "product_id", "updated_at"]

  COLLABORATION_USER_KEYS = ["id", "account_id", "name", "job_title", "email", "mobile", "phone", "created_at", "deleted", "helpdesk_agent", "is_admin"]
  REPORTS_USER_KEYS = ["id", "account_id"]
  
  COLLABORATION_TICKET_KEYS = ["id", "responder_id", "status", "subject", "visible", "account_id", "display_id"]
  
  IRIS_USER_KEYS = REPORTS_USER_KEYS

  EXPORT_TICKET_KEYS          = ["id", "company_id", "requester_id"]
  EXPORT_USER_KEYS            = ["id"]

end

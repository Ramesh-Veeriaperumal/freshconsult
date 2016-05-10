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
    
  CRUD_KEYS_BY_TOKEN = Hash[*CRUD_COMBINATIONS.map {|c| [c[0], c[2]] }.flatten ]
  CRUD_NAMES_BY_KEY = Hash[*CRUD_COMBINATIONS.map {|c| [c[2], c[1]] }.flatten(1) ]
  CRUD_TOKENS_BY_NAME = Hash[*CRUD_COMBINATIONS.map {|c| [c[0], c[1]] }.flatten(1) ]
  
  
  MODELS = [
    [  'ticket',              CRUD_KEYS_BY_TOKEN[:all],                 'ticket'          ],
    [  'ticket_old_body',     CRUD_KEYS_BY_TOKEN[:update],              'ticket'          ],
    [  'subscription',        CRUD_KEYS_BY_TOKEN[:create_and_destroy],  'ticket'          ],
    [  'ticket_state',        CRUD_KEYS_BY_TOKEN[:update],              'ticket'          ],
    [  'note',                CRUD_KEYS_BY_TOKEN[:all],                 'note'            ],
    [  'schema_less_note',    CRUD_KEYS_BY_TOKEN[:update],              'note'            ],
    [  'archive_ticket',      CRUD_KEYS_BY_TOKEN[:create_and_update],   'archive_ticket'  ],
    [  'archive_note',        CRUD_KEYS_BY_TOKEN[:create],              'archive_note'    ],
    [  'company',             CRUD_KEYS_BY_TOKEN[:all],                 'company'         ],
    [  'company_domain',      CRUD_KEYS_BY_TOKEN[:create_and_destroy],  'company'         ],
    [  'user',                CRUD_KEYS_BY_TOKEN[:all],                 'user'            ],
    [  'user_email',          CRUD_KEYS_BY_TOKEN[:all],                 'user'            ],
    [  'topic',               CRUD_KEYS_BY_TOKEN[:all],                 'topic'           ],
    [  'post',                CRUD_KEYS_BY_TOKEN[:all],                 'post'            ],
    [  'article',             CRUD_KEYS_BY_TOKEN[:all],                 'article'         ],
    [  'tag',                 CRUD_KEYS_BY_TOKEN[:all],                 'tag'             ],
    [  'tag_use',             CRUD_KEYS_BY_TOKEN[:create_and_destroy],  'tag_use'         ],
    [  'account',             CRUD_KEYS_BY_TOKEN[:destroy],             'account'         ]
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
  
  RMQ_REPORTS_TICKET_KEY         = "*.1.#"
  RMQ_REPORTS_NOTE_KEY           = "*.1.#"
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

  AUTO_REFRESH_TICKET_KEYS = ["id", "display_id", "tag_names", "account_id", "user_id", "responder_id", "group_id", "status", 
    "priority", "ticket_type", "source", "requester_id", "due_by", "created_at"
  ]

  REPORTS_TICKET_KEYS = ["display_id", "id", "account_id", "agent_id", "group_id", 
    "product_id", "company_id", "status", "priority", "source", "requester_id", "ticket_type", 
    "visible", "sla_policy_id", "is_escalated", "fr_escalated", "resolved_at", 
    "time_to_resolution_in_bhrs", "time_to_resolution_in_chrs", "inbound_count",
    "first_response_by_bhrs", "first_assign_by_bhrs", "created_at", "archive",
    # columns stored in reports_hash in schema_less_ticket
    "first_response_id", "agent_reassigned_count", "group_reassigned_count", "reopened_count", 
    "private_note_count", "public_note_count", "agent_reply_count", "customer_reply_count",
    "agent_assigned_flag", "agent_reassigned_flag", "group_assigned_flag", "group_reassigned_flag"
  ]
  
  REPORTS_ARCHIVE_TICKET_KEYS = REPORTS_TICKET_KEYS

  AUTO_REFRESH_NOTE_KEYS = ["kind", "private"]

  REPORTS_NOTE_KEYS = ["id", "source", "user_id", "agent", "category", "private", "incoming", "deleted", "account_id", "created_at", "archive"]
  
end
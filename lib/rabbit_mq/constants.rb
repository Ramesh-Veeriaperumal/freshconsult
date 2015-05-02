module RabbitMq::Constants
  
  CRUD = ["create", "update", "destroy"]
  
  CONNECTION_TIMEOUT = 0.5
  
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
    [ "ticket",              CRUD_KEYS_BY_TOKEN[:all] ,                     "ticket"    ],
    [  "note",               CRUD_KEYS_BY_TOKEN[:create_and_destroy] ,      "ticket"    ],
    [  "schema_less_note",   CRUD_KEYS_BY_TOKEN[:update],                   "ticket"    ]
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

  AUTO_REFRESH_TICKET_KEYS = ["id", "display_id", "tag_names", "account_id", "user_id", "responder_id", "group_id", "status", 
    "priority", "ticket_type", "source", "requester_id", "due_by", "created_at"
  ]
  
end
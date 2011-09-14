account = Account.current

 def self.deleted_condition(input)
    { "condition" => "deleted", "operator" => "is", "value" => input}
  end
  
  def self.spam_condition(input)
    { "condition" => "spam", "operator" => "is", "value" => input}
  end
  
  DEFAULT_CUSTOM_FILTERS ={ 
    "My Open Tickets" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:open]},{ "condition" => "responder_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "My Resolved Tickets" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved]},{ "condition" => "responder_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "My Closed Tickets" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]},{ "condition" => "responder_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "My Tickets Due Today" => [{ "condition" => "due_by", "operator" => "due_by_op", "value" => TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_today]},{ "condition" => "responder_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "My Overdue Tickets" => [{ "condition" => "due_by", "operator" => "due_by_op", "value" => TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:all_due]},{ "condition" => "responder_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "My Tickets On Hold" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:pending]},{ "condition" => "responder_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "Open Tickets in My Groups" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:open]},{ "condition" => "group_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "New Tickets in My Groups" => [{ "condition" => "responder_id", "operator" => "is_in", "value" => "" },{ "condition" => "group_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "Pending tickets in My Groups" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:pending]},{ "condition" => "group_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "New Tickets" => [{ "condition" => "responder_id", "operator" => "is_in", "value" => "" },spam_condition(false),deleted_condition(false)],
    "Open Tickets" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:open]},spam_condition(false),deleted_condition(false)],
    "Closed Tickets" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]},spam_condition(false),deleted_condition(false)],
    "Resolved Tickets" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved]},spam_condition(false),deleted_condition(false)],
    "Tickets on Hold" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:pending]},spam_condition(false),deleted_condition(false)],
    "Tickets Due Today" => [{ "condition" => "due_by", "operator" => "due_by_op", "value" => TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_today]},spam_condition(false),deleted_condition(false)],
    "Tickets Overdue" => [{ "condition" => "due_by", "operator" => "due_by_op", "value" => TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:all_due]},spam_condition(false),deleted_condition(false)],
    "All My Tickets" => [{ "condition" => "responder_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "All Tickets in My Groups" => [{ "condition" => "group_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "All Tickets" => [spam_condition(false),deleted_condition(false)],
    "New and My Open Tickets" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:open]},{ "condition" => "responder_id", "operator" => "is_in", "value" => "-1,0" },spam_condition(false),deleted_condition(false)]
 
   }
   
   filter_array = []
   
   DEFAULT_CUSTOM_FILTERS.each do |name,filter_data|
    filter_array.push({:account_id => account.id,:name  => name,:match => :and,:model_class_name => 'Helpdesk::Ticket',:query_hash => filter_data,
                       :visibility => {:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents], :user_id => account.account_admin.id}})  
   end
    
   Helpdesk::Filters::CustomTicketFilter.seed_many(:account_id,:name,filter_array)









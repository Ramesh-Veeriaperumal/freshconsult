account = Account.current

 def self.deleted_condition(input)
    { "condition" => "deleted", "operator" => "is", "value" => input}
  end
  
  def self.spam_condition(input)
    { "condition" => "spam", "operator" => "is", "value" => input}
  end
  
   DEFAULT_CUSTOM_FILTERS ={ 
    "My Open and Pending Tickets" => [{ "condition" => "status", "operator" => "is_in", "value" => "#{TicketConstants::STATUS_KEYS_BY_TOKEN[:open]},#{TicketConstants::STATUS_KEYS_BY_TOKEN[:pending]}"},{ "condition" => "responder_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "My Overdue Tickets" => [{ "condition" => "due_by", "operator" => "due_by_op", "value" => TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:all_due]},{ "condition" => "responder_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "Open Tickets in My Groups" => [{ "condition" => "group_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
    "Urgent and High priority tickets" => [{ "condition" => "priority", "operator" => "is_in", "value" => "#{TicketConstants::PRIORITY_KEYS_BY_TOKEN[:urgent]},#{TicketConstants::PRIORITY_KEYS_BY_TOKEN[:high]}" },spam_condition(false),deleted_condition(false)]
     
   }
   
   filter_array = []
   
   DEFAULT_CUSTOM_FILTERS.each do |name,filter_data|
    filter_array.push({:account_id => account.id,:name  => name,:match => :and,:model_class_name => 'Helpdesk::Ticket',:query_hash => filter_data,
                       :visibility => {:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents], :user_id => account.account_admin.id}})  
   end
    
   Helpdesk::Filters::CustomTicketFilter.seed_many(:account_id,:name,filter_array)









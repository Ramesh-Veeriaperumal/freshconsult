class AddDefaultCustomViews < ActiveRecord::Migration
  
#  def self.deleted_condition(input)
#    { "condition" => "deleted", "operator" => "is", "value" => input}
#  end
#  
#  def self.spam_condition(input)
#    { "condition" => "spam", "operator" => "is", "value" => input}
#  end
#  
#  DEFAULT_CUSTOM_FILTERS ={ 
#    "My Open and Pending Tickets" => [{ "condition" => "status", "operator" => "is_in", "value" => "#{TicketConstants::STATUS_KEYS_BY_TOKEN[:open]},#{TicketConstants::STATUS_KEYS_BY_TOKEN[:pending]}"},{ "condition" => "responder_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
#    "My Overdue Tickets" => [{ "condition" => "due_by", "operator" => "due_by_op", "value" => TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:all_due]},{ "condition" => "responder_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
#    "Open Tickets in My Groups" => [{ "condition" => "group_id", "operator" => "is_in", "value" => 0 },spam_condition(false),deleted_condition(false)],
#    "Urgent and High priority tickets" => [{ "condition" => "priority", "operator" => "is_in", "value" => "#{TicketConstants::PRIORITY_KEYS_BY_TOKEN[:urgent]},#{TicketConstants::PRIORITY_KEYS_BY_TOKEN[:high]}" },spam_condition(false),deleted_condition(false)]
#     
#   }
  
  def self.up
     #This is done through back ground job
#    Account.find(:all,:conditions => ["deleted_at is NULL"]).each do |account|
#     DEFAULT_CUSTOM_FILTERS.each do |name,filter_data|
#      ticket_filter = account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME)
#      ticket_filter.name = name
#      ticket_filter.match = :and
#      ticket_filter.model_class_name = 'Helpdesk::Ticket'
#      ticket_filter.query_hash = filter_data
#      ticket_filter.visibility = {:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents], :user_id => account.account_admin.id}
#      ticket_filter.account_id = account.id
#      ticket_filter.save
#     end
#    end
    
  end

  def self.down
  end
 

end

class VirtualAgentsController < ApplicationController  
  def index
  end
  
  def new   
    @virtual_agent = VirtualAgent.new
    logger.debug "Inside VA controller"
    default_filter_hash    = [{:name => 0              , :value => "--- Click to Select Filter ---"},
                      {:name => "from_email_id", :value => "From Email Id", :domtype => "autocompelete", :autocompelete_url => "allemailsurl" },
                      {:name => "to_email_id"  , :value => "To Email Id"  , :domtype => "autocompelete", :autocompelete_url => "allemailsurl" },
                      {:name => 0              , :value => "------------------------------"},
                      {:name => "subject"      , :value => "Subject",       :domtype => "text" },
                      {:name => "description"  , :value => "Description...",   :domtype => "paragraph" },
                      {:name => "priority"     , :value => "Priority",      :domtype => "dropdown", :choices => [{:name => "1", :value => "Low"}, 
                                                                                                                 {:name => "2", :value => "Medium"}, 
                                                                                                                 {:name => "3", :value => "High"}, 
                                                                                                                 {:name => "4", :value => "Urgent"}] },
                      {:name => "tag"          , :value => "Tag",           :domtype => "autocompelete", :autocompelete_url => "alltagsurl" },
                      {:name => "type"         , :value => "Type",          :domtype => "dropdown", :choices => [{:name => "1", :value => "Incident"}, 
                                                                                                                 {:name => "2", :value => "Question"}, 
                                                                                                                 {:name => "3", :value => "Problem"}] },
                      {:name => "status"       , :value => "Status",        :domtype => "dropdown", :choices => [{:name => "open", :value => "Open"}, 
                                                                                                                 {:name => "closed", :value => "Closed"},
                                                                                                                 {:name => "resolved", :value => "Resolved"},
                                                                                                                 {:name => "onhold", :value => "On Hold"}] },
                      {:name => "source"       , :value => "Source",        :domtype => "dropdown", :choices => [{:name => "1", :value => "Email"}, 
                                                                                                                 {:name => "2", :value => "Phone"},
                                                                                                                 {:name => "3", :value => "Self Service"},
                                                                                                                 {:name => "4", :value => "Via Agent"}] },
                      {:name => 0              , :value => "------------------------------"},
                      {:name => "contact_name" , :value => "Contact Name",  :domtype => "autocompelete", :autocompelete_url => "contactnameurl" },
                      {:name => "company_name" , :value => "Company Name",  :domtype => "autocompelete", :autocompelete_url => "companynameurl" },
                      {:name => "support_plan" , :value => "Support Plan",  :domtype => "dropdown", :choices => [{:name => "1", :value => "Platinum"}, 
                                                                                                                 {:name => "2", :value => "Gold"}, 
                                                                                                               {:name => "3", :value => "Silver"}] }]
    filter_hash = add_custom_filters default_filter_hash
    
    logger.debug "virtual agents :: the filter is #{filter_hash.inspect}"
    
    @filter_defs   = ActiveSupport::JSON.encode filter_hash
    
    condition_hash  = [{:name => "is"          , :value => "is"         }, {:name => "is_not"          , :value => "is not"}, 
                       {:name => "contains"    , :value => "Contains"   }, {:name => "does_not_contain", :value => "Does not contain"}, 
                       {:name => "starts_with" , :value => "Starts with"}, {:name => "ends_with"       , :value => "Ends with"}]
                       
    @condition_defs = ActiveSupport::JSON.encode condition_hash
    
    action_hash     = [{:name => 0              , :value => "--- Click to Select Action ---"},
                       {:name => "s_priority"  , :value => "Set Priority as", :domtype => "dropdown" , :choices => [{:name => "1", :value => "Low"}, 
                                                                                                                  {:name => "2", :value => "Medium"}, 
                                                                                                                  {:name => "3", :value => "High"},
                                                                                                                  {:name => "4", :value => "Urgent"}] },
                       {:name => "s_type"       , :value => "Set Type as"    , :domtype => "dropdown" , :choices => [{:name => "1", :value => "Incident"}, 
                                                                                                                  {:name => "2", :value => "Question"}, 
                                                                                                                  {:name => "3", :value => "Problem"}] },
                       {:name => "s_status"     , :value => "Set Status as"  , :domtype => "dropdown" , :choices => [{:name => "open", :value => "Open"}, 
                                                                                                                  {:name => "closed", :value => "Closed"},
                                                                                                                  {:name => "resolved", :value => "Resolved"},
                                                                                                                  {:name => "onhold", :value => "On Hold"}]},
                       {:name => 0              , :value => "------------------------------"},                                                                                           
                       {:name => "add_comment"  , :value => "Add Comment as" , :domtype => 'comment'},
                       {:name => "add_tag"      , :value => "Add Tag(s)"  , :domtype => 'autocompelete', :autocompelete_url => "allemailsurl"},
                       {:name => 0              , :value => "------------------------------"},
                       {:name => "assign_to_agent" , :value => "Assign to Agent"  , :domtype => 'dropdown', :choices => [{:name => "1", :value => "Edward"}, 
                                                                                                                         {:name => "2", :value => "John Patrick"},
                                                                                                                         {:name => "3", :value => "Susan Renolds"},
                                                                                                                         {:name => "4", :value => "Gary Matheew"}]},
                       {:name => "assign_to_group" , :value => "Assign to Group"  , :domtype => 'dropdown', :choices => [{:name => "1", :value => "Hardware"}, 
                                                                                                                         {:name => "2", :value => "Software"},
                                                                                                                         {:name => "3", :value => "Tech support"},
                                                                                                                         {:name => "4", :value => "Product Group"}]},
                       {:name => 0              , :value => "------------------------------"},
                       {:name => "send_email_group" , :value => "Send Email to Group"  , :domtype => 'autocompelete', :autocompelete_url => "groupemailsurl"},
                       {:name => "send_email_agent" , :value => "Send Email to Agent"  , :domtype => 'autocompelete', :autocompelete_url => "agentemailsurl"},
                       {:name => "send_email_user"  , :value => "Send Email to User"   , :domtype => 'autocompelete', :autocompelete_url => "useremailsurl"},
                      ]
    
    
    
    @action_defs    = ActiveSupport::JSON.encode action_hash 
                                                                                 
  end
  
  def create
    @new_agent = params[:save_json]
    p ActiveSupport::JSON.decode @new_agent
    redirect_to virtual_agents_url
  end
  
  def edit
  end
  
  def update
  end
  
  def destroy
end

protected

def add_custom_filters filter_hash
  
   @ticket_field = Helpdesk::FormCustomizer.find(:first ,:conditions =>{:account_id => current_account.id})
   
   @json_data = ActiveSupport::JSON.decode(@ticket_field.json_data)
   
   @json_data.each do |field|
     
     if field["fieldType"].eql?("custom")
       
        item = {:name =>  field["label"] , :value =>  field["label"] ,  :domtype => field["type"], :action => "set_custom_field" }
        filter_hash.push(item)
     end
     
   end
   
  return filter_hash
 
end
  
end

module Import::Zen::User
 
 ZENDESK_ROLE_MAP = {0 =>3, 4 => 2, 2 => 1 }
 
 class UserProp < Import::FdSax   
   element :id , :as => :import_id
   element :name
   element :email
   element :phone
   element :roles  , :as => :user_role
   element "time-zone" , :as => :time_zone
   element "organization-id", :as => :customer_id
 end
 
 def save_user user_xml
  user_prop = UserProp.parse(user_xml)
  customer =  @current_account.customers.find_by_import_id(user_prop.customer_id) 
  customer_id = customer.id if customer
  user_params = {:user =>user_prop.to_hash.merge({:customer_id =>customer_id, :user_role => ZENDESK_ROLE_MAP[user_prop.user_role.to_i]})}
  user = @current_account.all_users.find(:first, :conditions =>['email=? or import_id=?',user_prop.email,user_prop.import_id])
  unless user
    user = @current_account.users.new
    user.deleted = true unless user_prop.email
    user.signup!(user_params)
  else
    user.update_attribute(:import_id , user_prop.import_id )
  end
  Agent.find_or_create_by_user_id(user.id) unless user.customer?
 end

 
 
end
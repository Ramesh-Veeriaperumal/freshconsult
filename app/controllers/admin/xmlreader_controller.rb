class Admin::XmlreaderController < Admin::AdminController
  
    before_filter { |c| c.requires_permission :manage_tickets }
    
    require 'rexml/document'    
    require 'rexml/xpath'    
    
    include Import::CustomField
    include Import::Forums
  

  def zendesk_import
    
    base_dir = params[:base_dir]    
    file_list = params[:import][:files]
    
    create_solution = false
    user_activation_email = false
    
    import_list = file_list.reject(&:blank?)   
    
    @customers_stat = Hash.new
    @users_stat = Hash.new
    @groups_stat = Hash.new
    @tickets_stat = Hash.new
    ##setting current notification in thread
    set_notification_thread
    if import_list.include?("solution")
       create_solution = true
    end 
    
    if import_list.include?("user_notify")
       logger.debug "user_notify is enabled"
       user_activation_email = true   
    end    
    
    if import_list.include?("customers")
       Thread.current[:notifications][EmailNotification::USER_ACTIVATION][:requester_notification] = user_activation_email       
       @customers_stat = handle_customer_import base_dir
       @users_stat = handle_user_import base_dir  
    end
    if import_list.include?("tickets")
       disable_ticket_notification
       import_flexifields base_dir
       @groups_stat = handle_group_import base_dir
       @tickets_stat = handle_ticket_import base_dir       
    end
    if import_list.include?("forums")
       handle_forums_import base_dir , create_solution
    end  
    ##To enable all notifications
    enable_notifications
    del_file = FileUtils.rm_rf base_dir  
      
  end
  def set_notification_thread
    Thread.current[:notifications] = current_account.email_notifications
  end
  def disable_ticket_notification     
     Thread.current[:notifications][EmailNotification::NEW_TICKET][:requester_notification] = false
     Thread.current[:notifications][EmailNotification::TICKET_ASSIGNED_TO_GROUP][:agent_notification] = false
     Thread.current[:notifications][EmailNotification::TICKET_ASSIGNED_TO_AGENT][:agent_notification] = false
     Thread.current[:notifications][EmailNotification::TICKET_RESOLVED][:requester_notification] = false
     Thread.current[:notifications][EmailNotification::TICKET_CLOSED][:requester_notification] = false
     Thread.current[:notifications][EmailNotification::COMMENTED_BY_AGENT][:requester_notification] = false
     Thread.current[:notifications][EmailNotification::TICKET_REOPENED][:requester_notification] = false   
     Thread.current[:notifications][EmailNotification::REPLIED_BY_REQUESTER][:agent_notification] = false      
  end
  
  def enable_notifications
    Thread.current[:notifications] = nil
  end

def handle_customer_import base_dir
  
  file_path = File.join(base_dir , "organizations.xml")  
  created = 0
  updated = 0
  customer_count = Hash.new
  file = File.new(file_path) 
  doc = REXML::Document.new file
  
  REXML::XPath.each(doc,'//organization') do |org|       
     cust_name = nil
     cust_detail = nil
     import_id = nil     
     
     org.elements.each("name") {|name|  cust_name = name.text}     
     org.elements.each("details") {|detail| cust_detail = detail.text }    
     org.elements.each("id") { |imp_id| import_id = imp_id.text }    

     params = {:name =>cust_name , :description =>cust_detail , :import_id =>import_id}
     @customer = current_account.customers.find_by_import_id(import_id.to_i())
     unless @customer.blank?
        if @customer.update_attributes(params)
             updated+=1
        end      
     else
        @customer = current_account.customers.new(params)
        if @customer.save
            created+=1
            logger.debug "Customer has been saved with name:: #{cust_name}"
        else
            logger.debug "Save customer has been failed:: #{@customer.errors.inspect}"
        end
     end
     
  end

  customer_count["created"]=created
  customer_count["updated"]=updated
  return customer_count

end

def handle_group_import base_dir
  
  created = 0
  updated = 0

  group_count = Hash.new
  file_path = File.join(base_dir , "groups.xml")
  file = File.new(file_path) 
  doc = REXML::Document.new file
    
  REXML::XPath.each(doc,'//group') do |group|
    
     grp_name = nil
     grp_id = nil
          
     group.elements.each("name") do |name|      
       grp_name = name.text         
     end
     
     group.elements.each("id") do |groupid|      
       grp_id = groupid.text         
     end
     params = {:name =>grp_name, :import_id =>grp_id}
     @group = current_account.groups.find_by_import_id(grp_id.to_i())
     @group = current_account.groups.find_by_name(grp_name) if @group.blank?
     unless @group.blank?
        if @group.update_attributes(params)
             updated+=1
        end      
     else
        @group = current_account.groups.new(params)
        if @group.save
            created+=1
            logger.debug "Group has been saved with name:: #{grp_name}"
        else
            logger.debug "Save group has been failed:: #{@group.errors.inspect}"
        end
     end
  end
  group_count["created"]=created
  group_count["updated"]=updated
  return group_count

end

def handle_user_import base_dir
  created = 0
  updated = 0

  user_count = Hash.new
  
  file_path = File.join(base_dir , "users.xml")
  file = File.new(file_path) 
  doc = REXML::Document.new file
    
  REXML::XPath.each(doc,'//user') do |user|    
    
     usr_name = nil
     usr_email = nil
     usr_phone = nil
     usr_role = 3
     usr_time_zone = nil
     usr_details = nil 
     org_id = nil
     import_id = nil
     created_at = nil
     
     user.elements.each("name") do |name|  
     usr_name = name.text         
     end
   
     user.elements.each("email") do |email|           
      usr_email = email.text         
     end  
   
     user.elements.each("phone") do |phone|            
       usr_phone = phone.text         
     end  
   
     user.elements.each("roles") do |role|     
       role_id = role.text 
       role_id = role_id.to_i()
       logger.debug "role_id is :: #{role_id}"  
       
       usr_role = 1 if role_id == 2
       usr_role = 2 if role_id == 4
       usr_role = 3 if role_id == 0       
     end  
   
     user.elements.each("time-zone") do |time_zone|   
       usr_time_zone = time_zone.text    
       logger.debug "user time zone is #{usr_time_zone.inspect}"
     end 
   
     user.elements.each("details") do |details|      
       usr_details = details.text         
     end
     
     user.elements.each("organization-id") do |org|       
       cust_id = org.text
       logger.debug "Cust id while importing is :: #{cust_id}"
       customer = current_account.customers.find_by_import_id(cust_id) 
       org_id = customer.id unless customer.blank?
     end
     
     user.elements.each("id") do |import|      
       import_id = import.text         
     end
     
     #user.elements.each("created-at") do |created|      
      # created_time = created.text         
       #created_at = created_time.to_datetime()
     #end
     
     logger.debug "The email iss :: #{usr_email}"
     
     @params_hash ={ :user => { :name => usr_name,
                                :job_title => "",
                                :phone => usr_phone,
                                :email =>  usr_email,
                                :twitter_id => nil, 
                                :customer_id => org_id,
                                :import_id => import_id,
                                :user_role => usr_role,
                                :time_zone =>usr_time_zone,
                              }
                     }     
     @user = nil
     unless usr_email.blank?
      @user= current_account.all_users.find_by_email(usr_email)    
     end
     @user = current_account.all_users.find_by_import_id(import_id) if @user.blank?     
     logger.debug "email is :: #{usr_email} and import id :: #{import_id} and \n user: #{@user.inspect}"
     unless @user.blank?
          if @user.update_attributes(@params_hash[:user])
             updated+=1
              if usr_role != 3               
               @agent = Agent.find_or_create_by_user_id(@user.id )
           end
         else
            logger.debug "updation of the user has been failed :: #{@user.errors.inspect}"
          end
     else
          @user = current_account.users.new
          @user.time_zone = usr_time_zone
          if usr_email.blank?
              logger.debug "Import id is :: #{import_id}"
             #logger.debug "email is blank:: #{@user.inspect}"
             @user.deleted=true
             logger.debug  "after ::email is blank:: #{@user.inspect} is del: #{@user.deleted}"             
          end
          #@params_hash[:user][:user_role] = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
          if @user.signup!(@params_hash) 
            logger.debug "user has been save #{@user.inspect}"
            created+=1
            if usr_role != 3
               logger.debug "Its an agents and the user_id is :: #{@user.id}"
               @agent = Agent.create(:user_id =>@user.id )
            end
          else
            logger.debug "unable to create the user :: #{@user.errors.inspect}" 
          end
        
      end     
     logger.debug " The user data:: name : #{usr_name} e_mail : #{usr_email} :: phone :: #{usr_phone} :: role :: #{usr_role} time_zone :: #{usr_time_zone} and usr_details :#{usr_details}"

 end
 user_count["created"]=created
 user_count["updated"]=updated
 return user_count
end

def handle_ticket_import base_dir
  
    
  created_count = 0
  updated_count = 0
  ticket_count = Hash.new
  file_path = File.join(base_dir , "tickets.xml")
  file = File.new(file_path) 
  doc = REXML::Document.new file
  
  REXML::XPath.each(doc,'//ticket') do |req| 
        
      sub = nil 
      desc = nil
      requester_id = nil
      assignee_id = nil
      status_id = nil
      priority_id = nil
      ticket_type_id = nil
      tags= nil
      due_date = nil
      group_id = nil
      display_id = nil  #nice_id
      created_at = nil
      updated_at = nil      
      resolution_time= nil
      import_id = nil
        
      req.elements.each("subject") do |subject|       
        sub = subject.text         
      end
        
      req.elements.each("description") do |description|  
        desc = description.text
      end 
      
      req.elements.each("requester-id") do |requester|  
        req_id = requester.text.to_i()
        requester_id = current_account.all_users.find_by_import_id(req_id).id       
      end  
      
      req.elements.each("assignee-id") do |assignee|  
        assign_id = assignee.text
        assignee_id = current_account.all_users.find_by_import_id(assign_id.to_i()).id unless assign_id.blank?
        
      end  
      
      req.elements.each("status-id") do |status|  
        stat_id = status.text.to_i()
        status_id = 2 if stat_id == 1
        status_id = 3 if stat_id == 2
        status_id = 4 if stat_id == 3
        
      end 
      
      req.elements.each("priority-id") do |priority|  
        priority_id = priority.text.to_i()
        priority_id = 1 if priority_id < 1
        
      end 
      
      req.elements.each("ticket-type-id") do |ticket_type|  
        ticket_type_id = ticket_type.text
      end      
     
      
      req.elements.each("group-id") do |group|  
        imp_id = group.text        
        group_id = current_account.groups.find_by_import_id(imp_id.to_i()).id unless imp_id.blank?
      end 
      
      req.elements.each("nice-id") do |display|  
        display_id = display.text
      end 
      
      req.elements.each("created-at") do |created|  
        created_time = created.text
        created_at = created_time.to_datetime()
      end 
     
      req.elements.each("updated-at") do |updated|  
        updated_at = updated.text
        updated_at = updated_at.to_datetime()
      end 
      
      req.elements.each("resolution-time") do |res|  
        resolution_time = res.text
      end       
        
      req.elements.each("current-tags") do |tag|  
        tags = tag.text
      end 
      
      req.elements.each("due-date") do |due|  
        due_date = due.text
      end 
      
      @request = current_account.tickets.find_by_import_id(display_id.to_i())    
     
      if @request.blank?
        @request = current_account.tickets.new 
        created_count+=1
      else
        updated_count+=1
        next
      end
      
      @display_id_exist = current_account.tickets.find_by_display_id(display_id.to_i())
      
      @request.subject = sub
      @request.description = desc
      @request.requester_id = requester_id
      @request.responder_id = assignee_id
      @request.group_id = group_id
      @request.display_id = display_id if @display_id_exist.blank?
      @request.import_id = display_id
      @request.status = status_id
      @request.priority = priority_id
      @request.ticket_type = ticket_type_id.to_i()
      @request.created_at = created_at
      @request.updated_at = updated_at
      

      if @request.save         
        logger.debug "successfully saved"
      else
        logger.debug "failed to save the ticket :: #{@request.errors.inspect}"
      end
      
      ## Create attachemnts

      req.elements.each("attachments/attachment") do |attach|         
        attachemnt_url = nil        
        attach.elements.each("url") {|attach_url|   attachemnt_url = attach_url.text  } 
        Delayed::Job.enqueue Import::Attachment.new(@request.id ,attachemnt_url, :ticket )
       
      end
      
      ####handling additional fields

      ff_def_id = FlexifieldDef.find_by_account_id(@request.account_id).id        
      custom_field = Hash.new      
      req.elements.each("ticket-field-entries/ticket-field-entry") do |add_field|          
       cust_import_id = nil
       field_val = nil
       field_type = nil
       lable =nil       
       add_field.elements.each("ticket-field-id") do |ticket_field|
          cust_import_id = ticket_field.text          
       end      
      
       add_field.elements.each("value") do |field_value|
          field_val = field_value.text          
       end
       @flexifield_def_entries = FlexifieldDefEntry.first(:conditions =>{:flexifield_def_id => ff_def_id ,:import_id => cust_import_id.to_i()})
       
       unless @flexifield_def_entries.blank?
         label = @flexifield_def_entries.flexifield_alias  
       else
         next
       end
       
       custom_field[label] = field_val
    end
    
    ##saving custom_field
  
    @request.ff_def = ff_def_id       
    unless custom_field.nil?          
      @request.assign_ff_values custom_field    
    end
    
      ##handling notes ---
      
      first_comment = true
      req.elements.each("comments/comment") do |comment|
       if first_comment
         first_comment = false
         next
       end
       note_body = nil
       note_created_by = nil
       note_created_time = nil
       is_public = false
       incoming = false
       #logger.debug "post :: #{post.inspect}"
       
       comment.elements.each("value") { |val| note_body =  val.text } 
       comment.elements.each("is-public") { |public| is_public =  public.text } 
       comment.elements.each("created-at") { |created_time| note_created_time =  created_time.text } 
       
       comment.elements.each("author-id") do |author|
          author_id = author.text
          note_created = current_account.all_users.find_by_import_id(author_id.to_i())              
          note_created_by = note_created.id unless note_created.blank?            
          incoming = true if note_created.customer?
       end
       
        @note = @request.notes.build({
        :incoming => incoming,
        :private => is_public,
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
        :user_id => note_created_by,
        :account_id =>current_account && current_account.id,
        :body =>note_body        
        })
         @note.created_at = note_created_time.to_datetime()
         if @note.save
           logger.debug "successfully saved"
         else
            logger.debug "failed to save the note :: #{@note.errors.inspect}"
         end
        
        ##adding attachment to notes
        comment.elements.each("attachments/attachment") do |attach| 
        
        attachemnt_url = nil        
        attach.elements.each("url") {|attach_url|   attachemnt_url = attach_url.text  } 
        Delayed::Job.enqueue Import::Attachment.new(@note ,attachemnt_url , :note )
        end

    end
     #---note saving ends--
       
   end   
   ticket_count["created"]=created_count
   ticket_count["updated"]= updated_count
   return ticket_count
end

#This is helpdesk rebranding....
#
def handle_account_import base_dir
  
  logger.debug "Here its :: handle_account_import"
  created = 0
  updated = 0
  file_path = File.join(base_dir , "accounts.xml")
  file = File.new(file_path) 
  doc = REXML::Document.new file   
  reply_address = nil
  acc_name = nil
  time_zone = nil
  import_id = nil
  
  doc.elements.each("account/reply-address") { |address| reply_address =  address.text }  
  doc.elements.each("account/name") { |name| acc_name = name.text }
  doc.elements.each("account/time-zone") { |timezone| time_zone = timezone.text }  
  
end

def handle_forums_import base_dir,make_solution
  
  cat_path = File.join(base_dir , "categories.xml")  
  posts_path = File.join(base_dir , "posts.xml")
  entry_path = File.join(base_dir , "entries.xml")
  
  cat_import = Hash.new
  @forum_stat = Hash.new
  @topic_stat = Hash.new
  
  cat_import = import_forum_categories cat_path  
  @forum_stat = get_forum_data base_dir,make_solution  
  @topic_stat = get_entry_data entry_path , make_solution
  
  get_posts_data posts_path
  
end

end

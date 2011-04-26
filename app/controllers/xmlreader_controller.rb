class XmlreaderController < ApplicationController
  
    require 'rexml/document'
    
    require 'rexml/xpath'
  
  def xmlreader
  end

  def importxml
    
    puts "inside import xml"
    
    file=params[:dump][:file]
    
    doc=REXML::Document.new(file.read)  

    # terating ticket elements
    REXML::XPath.each(doc,'//ticket') do |req| 
        
        sub = nil 
        desc = nil
        import_id = nil
        
        #filtering each fields
        
        req.elements.each("subject") do |subject|
          
          puts "subject value is"       
        
          sub = subject.text
         
        end
        
        req.elements.each("description") do |description|    
       
          desc = description.text
         
        end    
       
       puts sub
       
       puts desc
       
       # saving the data to ticket
       
       @request = Helpdesk::Ticket.new(:subject => sub, :description =>desc, :account_id => '1')      
      
       @request.save
        
       end
  end
  
  def zendesk_import
    
    logger.debug "import zendesk :: is #{params.inspect}"
    
    base_dir = params[:base_dir]
    
    file_list = params[:import][:files]
    
    logger.debug "initial arr size:: #{ file_list.size} :: and compact one is #{file_list.reject(&:blank?).size} "    
    
    import_list = file_list.reject(&:blank?)   
    
    if import_list.include?("customers")
       handle_customer_import base_dir
       handle_user_import base_dir  
    end
    if import_list.include?("tickets")        
       handle_group_import base_dir
       handle_ticket_import base_dir
    end
    if import_list.include?("forums")
       handle_forums_import base_dir
    end    
   
  end

def handle_customer_import base_dir
  
  file_path = File.join(base_dir , "organizations.xml")
  
  created = 0
  updated = 0
  file = File.new(file_path) 
  doc = REXML::Document.new file
    
  REXML::XPath.each(doc,'//organization') do |org|    
    
     cust_name = nil
     cust_detail = nil
     import_id = nil     
     
     org.elements.each("name") do |name|      
       cust_name = name.text         
     end
     
     org.elements.each("details") do |detail|      
       cust_detail = detail.text         
     end
     
     org.elements.each("id") do |imp_id|      
       import_id = imp_id.text         
     end
     
     @customer = current_account.customers.new(:name =>cust_name , :description =>cust_detail , :import_id =>import_id )
     logger.debug "The cust object is :: #{@customer.inspect}"
     @customer.save
     
     
     
     #logger.debug " The user data:: name : #{usr_name} e_mail : #{usr_email} :: phone :: #{usr_phone} :: role :: #{usr_role} time_zone :: #{usr_time_zone} and usr_details :#{usr_details}"
  end
  
end

def handle_group_import base_dir
  
  created = 0
  updated = 0
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
    
     @group = current_account.groups.new(:name =>grp_name, :import_id =>grp_id )
     @group.save
  end
  
  
end

def handle_user_import base_dir
  created = 0
  updated = 0
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
   
     user.elements.each("time_zone") do |time_zone|   
       usr_time_zone = time_zone.text         
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
     
     @params_hash ={ :user => { :name => usr_name,
                                :job_title => "",
                                :phone => usr_phone,
                                :email =>  usr_email,
                                :twitter_id => nil, 
                                :customer_id => org_id,
                                :import_id => import_id,
                                :user_role => usr_role,
                              }
                     }
     @user = current_account.users.find_by_email(usr_email)        
     unless @user.nil?
          if @user.update_attributes(@params_hash[:user])
             updated+=1
          end
     else
          @user = current_account.users.new
          #@params_hash[:user][:user_role] = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
          if @user.signup!(@params_hash)    
            created+=1
            if usr_role != 3
               logger.debug "Its an agents and the user_id is :: #{@user.id}"
               @agent = Agent.create(:user_id =>@user.id )
            end
          end
      end     
     logger.debug " The user data:: name : #{usr_name} e_mail : #{usr_email} :: phone :: #{usr_phone} :: role :: #{usr_role} time_zone :: #{usr_time_zone} and usr_details :#{usr_details}"
  end
  
end

def handle_ticket_import base_dir
  
  logger.debug "handle_ticket_import ::: "
  
  created = 0
  updated = 0
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
        requester_id = current_account.users.find_by_import_id(req_id).id       
      end  
      
      req.elements.each("assignee-id") do |assignee|  
        assign_id = assignee.text
        assignee_id = current_account.users.find_by_import_id(assign_id.to_i()).id unless assign_id.blank?
        
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
      
      
      
      ###########
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
    
       
      @request = current_account.tickets.new
      @request.subject = sub
      @request.description = desc
      @request.requester_id = requester_id
      @request.responder_id = assignee_id
      @request.group_id = group_id
      @request.display_id = display_id
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
      
      ##handling notes ---
      
      req.elements.each("comments/comment") do |comment|
       
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
          note_created = current_account.users.find_by_import_id(author_id.to_i())          
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
      end    
      
      
      logger.debug "The @request :: #{@request.notes.inspect}"
      
     
        
   end
  
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
  
  logger.debug "account import ::  #{reply_address} and acc_name :: #{acc_name} and time_zone :: #{time_zone}"
  
  
end

def handle_forums_import base_dir
  
  forum_path = File.join(base_dir , "forums.xml")
  posts_path = File.join(base_dir , "posts.xml")
  entry_path = File.join(base_dir , "entries.xml")
  
  get_forum_data forum_path
  
  get_entry_data entry_path
  
  get_posts_data posts_path
 
  
  
end

def get_forum_data file_path
  
  created = 0
  updated = 0
  file = File.new(file_path) 
  doc = REXML::Document.new file
  
  default_category = current_account.forum_categories.first
    
  REXML::XPath.each(doc,'//forum') do |forum|
    
     desc = nil
     name = nil
     forum_id = nil
     @category = nil
     import_id = nil
     forum_type = nil
     
     forum.elements.each("name") do |name|      
       name = name.text         
     end
     
     forum.elements.each("description") do |description|      
       desc = description.text         
     end
     forum.elements.each("display-type-id") do |display_type|      
       forum_type = display_type.text.to_i()   
       forum_type = 1 if forum_type == 3
     end
   
     forum.elements.each("category-id") do |cat|      
       categ_id = cat.text  
       logger.debug "categ_id :: #{categ_id}"
       @category = current_account.forum_categories.find_by_import_id(categ_id.to_i()) unless categ_id.blank?
       logger.debug "@category after categ_id_blank :: #{@category.inspect}"
       unless categ_id.blank?
          @category = add_forum_category categ_id if @category.blank?        
       else
          @category =  default_category      
       end
       logger.debug "@category after add/default :: #{@category.inspect}"
       
     end
   
     forum.elements.each("id") do |for_id|      
       forum_id = for_id.text         
   end
    
    logger.debug "category is :: #{@category.inspect}"
    #forum_type = Forum::TYPE_KEYS_BY_TOKEN[:howto]
   
     @forum = @category.forums.build(:name =>name, :description => desc , :import_id =>forum_id.to_i(), :description_html =>desc ,:forum_type =>forum_type )
     @forum.account_id ||= current_account.id
     if @forum.save
     logger.debug "successfully saved the forum::"
     else     
      @forum = @category.forums.find_by_name(name)
      unless @forum.nil?
        @forum.update_attribute(:import_id, forum_id.to_i())
      end
     logger.debug "error while saving the forum:: #{@forum.errors.inspect}"
     end
  end
end

def add_forum_category cat_id
  
  logger.debug "inside add categories"
  cat_name = current_account.name+" forum_"+cat_id.to_s()
  @category = current_account.forum_categories.create(:name =>cat_name,:import_id => cat_id.to_i() )
 
end

##an entry is equivalent to topic in freshdesk
def get_entry_data file_path
  
  created = 0
  updated = 0
  file = File.new(file_path) 
  doc =  REXML::Document.new file
    
  REXML::XPath.each(doc,'//entry') do |entry|
    
     body = nil
     forum_id = nil
     submitter_id = nil
     title = nil
     import_id = nil
     topic_id = nil
     stamp_type = nil
     
     entry.elements.each("body") do |body|      
       body = body.text         
     end
     
     entry.elements.each("forum-id") do |forum|      
       forum_id = forum.text         
     end
   
     entry.elements.each("submitter-id") do |submitter|      
       user = submitter.text 
       submitter_id = current_account.users.find_by_import_id(user.to_i()).id unless user.blank?
     end
   
     entry.elements.each("title") do |forum_title|      
       title = forum_title.text         
     end
     
     entry.elements.each("id") do |import|      
       import_id = import.text         
     end    
     
     entry.elements.each("flag-type-id") do |stamp|
       stamp_type = stamp.text.to_i() unless stamp.blank?
       stamp_type = 1 if stamp_type == 200
       stamp_type = 2 if stamp_type == 201
       stamp_type = 3 if stamp_type == 300       
     end
     
    @topic_old = Topic.find_by_import_id(import_id)
     
    next unless @topic_old.blank?
     
    @forum      = Forum.find_by_import_id_and_account_id(forum_id.to_i(), current_account.id)
   
    
    @topic      = @forum.topics.build(:title =>title) 
    @topic.import_id = import_id
    @topic.user_id = submitter_id
    @topic.account_id = current_account.id
    @topic.stamp_type = stamp_type
    topic_saved = @topic.save
    @post = @topic.posts.build(:body =>body)
    @post.account_id = current_account.id
    @post.body_html = body
    @post.forum_id = @forum.id
    @post.user_id = submitter_id
    
    @post.save
   
     
    ## we may need to create the forum...first and then posts
     
    entry.elements.each("posts/post") do |post|
       
       post_body = nil
       created_by = nil
       
       post.elements.each("body") do |p_body|
         post_body = p_body.text
       end
       
       post.elements.each("user-id") do |post_user|
         user = post_user.text         
         created_by = current_account.users.find_by_import_id(user.to_i()).id unless user.blank?
       end     
       
        @post =  @topic.posts.build(:account_id =>current_account.id , :body_html =>post_body, :forum_id =>@forum.id, :user_id =>created_by )
        @post.save
        
     end
     
     
     
  end
  
end

def get_posts_data file_path
  
  created = 0
  updated = 0
  file = File.new(file_path) 
  doc = REXML::Document.new file
    
  REXML::XPath.each(doc,'//post') do |post|
    
     body = nil
     user_id = nil
     forum_id = nil
     
     post.elements.each("body") do |body|      
       body = body.text         
     end
     
     post.elements.each("forum-id") do |forum|      
       forum_id = forum.text         
     end
   
     post.elements.each("user-id") do |user|      
       user_id = user.text         
     end
   
   
  end
  
end

end

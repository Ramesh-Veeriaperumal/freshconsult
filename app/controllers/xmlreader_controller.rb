class XmlreaderController < ApplicationController
  
    require 'rexml/document'
    
    require 'rexml/xpath'
  
  def xmlreader
  end

  def importxml
   
  end
  
  def zendesk_import
    
    logger.debug "import zendesk :: is #{params.inspect}"
    
    base_dir = params[:base_dir]    
    file_list = params[:import][:files]
    
    create_solution = false
    
    logger.debug "initial arr size:: #{ file_list.size} :: and compact one is #{file_list.reject(&:blank?).size} "    
    
    import_list = file_list.reject(&:blank?)   
    
    if import_list.include?("solution")
       create_solution = true
    end  
    
    if import_list.include?("customers")
       handle_customer_import base_dir
       handle_user_import base_dir  
    end
    if import_list.include?("tickets")       
       import_flexifields base_dir
       handle_group_import base_dir
       handle_ticket_import base_dir       
    end
    if import_list.include?("forums")
       handle_forums_import base_dir , create_solution
    end  
   
   #delete the directory...
   
   logger.debug "The base_dir for delete is :: #{base_dir}"
   
   del_file = FileUtils.rm_rf base_dir
  
      
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
     
     org.elements.each("name") {|name|  cust_name = name.text}     
     org.elements.each("details") {|detail| cust_detail = detail.text }    
     org.elements.each("id") { |imp_id| import_id = imp_id.text }    
    
     @customer = current_account.customers.new(:name =>cust_name , :description =>cust_detail , :import_id =>import_id )
     if @customer.save
       logger.debug "Customer has been saved with name:: #{cust_name}"
     else
       logger.debug "Save customer has been failed:: #{@customer.errors.inspect}"
     end
    
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
     @user = current_account.users.find_by_email(usr_email)        
     unless @user.nil?
          if @user.update_attributes(@params_hash[:user])
             updated+=1
              if usr_role != 3               
               @agent = Agent.find_or_create_by_user_id(@user.id )
             end
          end
     else
          @user = current_account.users.new
          @user.time_zone = usr_time_zone
          #@params_hash[:user][:user_role] = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
          if @user.signup!(@params_hash) 
            logger.debug "user has been save #{@user.inspect}"
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
      
      @check_req = current_account.tickets.find_by_display_id(display_id.to_i())      
      next unless  @check_req.blank?    
       
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
      
      ## Create attachemnts

      req.elements.each("attachments/attachment") do |attach| 
        
        attachemnt_url = nil        
        attach.elements.each("url") {|attach_url|   attachemnt_url = attach_url.text  } 
        @request.attachments.create(:content => open(attachemnt_url), :description => "", :account_id => @request.account_id)
       
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
        
        ##adding attachment to notes
        comment.elements.each("attachments/attachment") do |attach| 
        
        attachemnt_url = nil        
        attach.elements.each("url") {|attach_url|   attachemnt_url = attach_url.text  } 
        @note.attachments.create(:content => open(attachemnt_url), :description => "", :account_id => @note.account_id)
       
        end
        
        
      end    
     
        
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

def handle_forums_import base_dir,make_solution
  
  cat_path = File.join(base_dir , "categories.xml")
  
  posts_path = File.join(base_dir , "posts.xml")
  entry_path = File.join(base_dir , "entries.xml")
  
  import_forum_categories cat_path
  
  get_forum_data base_dir,make_solution
  
  get_entry_data entry_path , make_solution
  
  get_posts_data posts_path
 
end

def get_forum_data base_dir,make_solution
  
  created = 0
  updated = 0
  file_path = File.join(base_dir , "forums.xml")
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
     display_type = nil
     
     forum.elements.each("name") do |name|      
       name = name.text         
     end
     
     forum.elements.each("description") do |description|      
       desc = description.text         
     end
     forum.elements.each("display-type-id") do |display_type|      
       display_type = display_type.text.to_i() 
       forum_type = display_type
       forum_type = 1 if display_type == 3
     end
     
     if make_solution && display_type ==1
       make_solution_folder forum, base_dir
       next
     end
   
     forum.elements.each("category-id") do |cat|      
       categ_id = cat.text  
       logger.debug "categ_id :: #{categ_id}"
       @category = current_account.forum_categories.find_by_import_id(categ_id.to_i()) unless categ_id.blank?
       logger.debug "@category after categ_id_blank :: #{@category.inspect}"      
       @category =  default_category if @category.blank?       
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

def make_solution_folder solution, base_dir
  
  cat_id = nil  
  folder_name = nil
  description = nil
  import_id = nil
  solution.elements.each("category-id") {|cat| cat_id = cat.text}
  solution.elements.each("name") {|folder| folder_name = folder.text}
  solution.elements.each("description") {|desc| description = desc.text}
  solution.elements.each("id") {|import| import_id  = import.text}
  
  @category = nil
  
  unless cat_id.blank?    
    @category = current_account.solution_categories.find_by_import_id(cat_id.to_i())
    @category = add_solution_category(base_dir, cat_id) if @category.blank?
  else
    @category = current_account.solution_categories.find_by_name("General")  
  end
  logger.debug "@category is #{@category.inspect}"
  @folder = @category.folders.new
  @folder.name = folder_name
  @folder.description= description
  @folder.import_id = import_id
  
  if @folder.save
    logger.debug "Folder has been saved successfully"
  else
    logger.debug "unable to save the folder #{@folder.errors.inspect}"
  end
  
end

def add_solution_category base_dir, cat_id
  
  created = 0
  updated = 0
  file_path = File.join(base_dir , "categories.xml")
  file = File.new(file_path) 
  doc = REXML::Document.new file
    
  REXML::XPath.each(doc,'//category') do |cat|    
    
     cat_name = nil
     cat_desc = nil
     import_id = nil     
     
     cat.elements.each("name") do |name|      
       cat_name = name.text         
     end
     
     cat.elements.each("description") do |desc|      
       cat_desc = desc.text         
     end
     
     cat.elements.each("id") do |imp_id|      
       import_id = imp_id.text         
     end
     logger.debug "import_id is :: #{import_id}"
    @category = current_account.solution_categories.new(:name =>cat_name,:import_id => import_id.to_i(), :description =>cat_desc)
     
    if @category.save
     logger.debug "The @categ is saved succesfully"
    else
     logger.debug "Unable to save category #{@category.errors.inspect}"
    end
     
     return @category
     #logger.debug " The user data:: name : #{usr_name} e_mail : #{usr_email} :: phone :: #{usr_phone} :: role :: #{usr_role} time_zone :: #{usr_time_zone} and usr_details :#{usr_details}"
 end

  
end
##an entry is equivalent to topic in freshdesk
def get_entry_data file_path, make_solution
  
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
    
    if (@forum.blank? && make_solution)
      logger.debug "The forum is blank and make_solu:: #{make_solution}"
      @sol_folder = Solution::Folder.find_by_import_id(forum_id.to_i())
      add_solution_article entry ,@sol_folder unless @sol_folder.blank?
      next
    end
    
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

def add_solution_article article, curr_folder
  
    title = nil
    desc = nil
    import_id = nil
    forum_id= nil
    submitter_id = nil
    is_public = true
    
     article.elements.each("body") {|body| desc = body.text }    
     article.elements.each("forum-id") { |forum|  forum_id = forum.text }   
     article.elements.each("is-public") {|public| is_public = public.text } 
     article.elements.each("submitter-id") do |submitter|      
       user = submitter.text 
       submitter_id = current_account.users.find_by_import_id(user.to_i()).id unless user.blank?
     end
   
     article.elements.each("title") { |forum_title| title = forum_title.text }     
     article.elements.each("id") { |import|  import_id = import.text }        
  
    @article = curr_folder.articles.new
    
    @article.title = title
    @article.description = desc
    @article.import_id = import_id
    @article.user_id = submitter_id
    @article.title = title
    @article.desc_un_html = desc
    @article.account_id = current_account.id
    @article.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
    @article.art_type = Solution::Article::TYPE_KEYS_BY_TOKEN[:permanent]
    @article.is_public = is_public
    
    
    if @article.save
      logger.debug "Article has been saved succesfully"
    else
      logger.debug "Article saving has been failed #{@article.errors.inspect}"
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

def save_custom_field ff_alias , column_type , import_id
  
  ff_id =FlexifieldDef.first(:conditions =>{:account_id => current_account.id}).id
  
  @flexifield =FlexifieldDefEntry.find_by_import_id_and_flexifield_def_id(import_id,ff_id)
  
  return @flexifield.flexifield_alias unless @flexifield.blank?
  
  coltype ="text"
  
  if ("dropdown".eql?(column_type) || "text".eql?(column_type))
    coltype = ["text" , "dropdown"]
  else
    coltype = column_type
  end
  
  columnId = 0
  
  data = get_new_column_details coltype
  
  column_name = data["column_name"]
  
  ff_def_id = data["ff_def_id"]
  
  ff_order = data["ff_order"]
  
  logger.debug "type is #{column_type} and new_column#{column_name} and ff_def_id : #{ff_def_id} and ff_alias:: #{ff_alias.inspect} "
  
  #saving new column as Untitled
  
  @ff_entries = FlexifieldDefEntry.new(:flexifield_name =>column_name , :flexifield_def_id =>ff_def_id ,:flexifield_alias =>ff_alias , :flexifield_order =>ff_order +1, :flexifield_coltype =>column_type ,:import_id =>import_id.to_i())
 
  
  if @ff_entries.save    
     columnId = @ff_entries.id     
   else    
     logger.debug "error while saving the cusom field #{ff_alias} : Error:: #{@ff_entries.errors.inspect}"
     columnId = -1    
  end
  logger.debug "columnId inside  save methode :: #{columnId}"
  
 
  
  return columnId
  
  
end

def update_form_customizer field_prop, column_id, choices=[]
  @ticket_fields = Helpdesk::FormCustomizer.find(:first ,:conditions =>{:account_id => current_account.id})
  json_data = @ticket_fields.json_data
  @data = []
  @data = ActiveSupport::JSON.decode(json_data)
  req_view = @ticket_fields.requester_view
  @endUser = ActiveSupport::JSON.decode(req_view)
  
  cust_field = Hash.new  
  
  cust_field ={"label"=>field_prop["label"], "setDefault"=>0, "fieldType"=>"custom", 
                "action"=>"edit", "type"=>field_prop["type"], "agent"=>{"required"=>true, "closure"=>field_prop["agent_rqrd"]}, 
                "styleClass"=>"", "display_name"=>field_prop["display_name"], "description"=>"",
                "customer"=>{"required"=>field_prop["cust_rqrd"] , "editable"=>field_prop["cust_editable"], "visible"=>field_prop["cust_visible"]}, 
                "columnId"=>column_id, "choices"=>choices}
                
   @data.push(cust_field)
   
   
    if field_prop["cust_visible"].eql?(true)      
      @endUser.push(cust_field) 
    end
   
    modified_json = ActiveSupport::JSON.encode(@data)
    requester_json = ActiveSupport::JSON.encode(@endUser)
    logger.debug "@data :: before updating :: #{@data.inspect}"
    if @ticket_fields.update_attributes(:json_data =>modified_json, :agent_view =>@data , :requester_view => requester_json )  
       logger.debug "Custom fields successfully updated."     
    else  
       logger.debug "Custom updation failed."
    end
  
end

def get_new_column_details type
  
 
  data = Hash.new 
  
  ff_def_id =FlexifieldDef.first(:conditions =>{:account_id => current_account.id}).id
  
  @flexifield_def_entries = FlexifieldDefEntry.all(:conditions =>{:flexifield_def_id => ff_def_id ,:flexifield_coltype => type})
  
  logger.debug "here is the inspection #{@flexifield_def_entries.inspect}"
   
  @coulumn_used = []
   
  ff_order = 0
    
  @flexifield_def_entries.each do |entry|
      @coulumn_used.push(entry.flexifield_name) 
      
      ff_order = entry.flexifield_order
      
      end
 
   logger.debug "current occupaid columsn : #{@coulumn_used.inspect}"
     
     
  @column_exist = nil
    
  new_column = nil
 
  case type
    
  when ["text" , "dropdown"]
    
    @column_list = Helpdesk::FormCustomizer::CHARACTER_FIELDS
    
    @column_exist = @column_list - @coulumn_used
    
    logger.debug "current exist : #{@column_exist.inspect}"
    
    new_column = @column_exist[0]
    
    logger.debug "new columns : #{new_column}"
    
  when "number"
    
    @column_list = Helpdesk::FormCustomizer::NUMBER_FIELDS
    
    @column_exist = @column_list - @coulumn_used
    
    logger.debug "current exist : #{@column_exist.inspect}"
    
    new_column = @column_exist[0]
    
    logger.debug "new columns : #{new_column}"
    
    
  when "checkbox"
    
    @column_list = Helpdesk::FormCustomizer::CHECKBOX_FIELDS
    
    @column_exist = @column_list - @coulumn_used
    
    logger.debug "current exist : #{@column_exist.inspect}"
    
    new_column = @column_exist[0]
    
    logger.debug "new columns : #{new_column}"
    
  when "date"
    
    @column_list = Helpdesk::FormCustomizer::DATE_FIELDS
    
    @column_exist = @column_list - @coulumn_used
    
    logger.debug "current exist : #{@column_exist.inspect}"
    
    new_column = @column_exist[0]
    
    logger.debug "new columns : #{new_column}"
    
 when "paragraph"
    
    @column_list = Helpdesk::FormCustomizer::TEXT_FIELDS
    
    @column_exist = @column_list - @coulumn_used
    
    logger.debug "current exist : #{@column_exist.inspect}"
    
    new_column = @column_exist[0]
    
    logger.debug "new columns : #{new_column}"
    
    
  end
  
  data ={"ff_def_id" =>ff_def_id, "ff_order" => ff_order,"column_name" =>new_column}
  
  return data
  

end

def get_file_from_zendesk  dest_path  
  
  logger.debug "Getting file from zendesk"
  
  url = 'http://uknowmewell12.zendesk.com/ticket_fields.xml'
  file_path = File.join(dest_path , "ticket_fields.xml") 
  
  import_file_from_zendesk url,file_path
  
  
  url = 'http://uknowmewell12.zendesk.com/categories.xml'
  file_path = File.join(dest_path , "categories.xml") 
  
  import_file_from_zendesk url,file_path
  
  
end

def import_file_from_zendesk url, file_path
  
  usr_name = "uknowmewell@gmail.com"
  usr_pwd = "Opmanager123$"
  
  url = URI.parse(url)  
  req = Net::HTTP::Get.new(url.path)  
  req.basic_auth usr_name, usr_pwd
  res = Net::HTTP.start(url.host, url.port) {|http| http.request(req) }     
  File.open(file_path, 'w') {|f| f.write(res.body) }
  logger.debug "successfully imported files from zendesk with file_path:: #{file_path.inspect}"
end

def import_flexifields base_dir
  
  file_path = File.join(base_dir , "ticket_fields.xml")
  created = 0
  updated = 0
  file = File.new(file_path) 
  doc = REXML::Document.new file
    
  REXML::XPath.each(doc,'//record') do |record|    
    
     field_type = nil
     cat_desc = nil
     import_id = nil
     title = nil
     agent_closure = false
     cust_rqrd = false
     cust_visible = false
     cust_editable = false
     
     
     
     record.elements.each("type") do |type|      
       field_type = type.text         
     end
     
     record.elements.each("title") do |title|      
       title = title.text         
     end
     
     logger.debug "The record title is  ::: #{title}"
     
     record.elements.each("id") do |obj_id|      
       import_id = obj_id.text         
     end
     
     record.elements.each("is-required") do |required|      
       agent_closure = required.text         
     end
     
     record.elements.each("is-required-in-portal") do |cust_rq|      
       cust_rqrd = cust_rq.text         
     end
     
     record.elements.each("is-visible-in-portal") do |cust_view|      
       cust_visible = cust_view.text         
     end
     
     record.elements.each("is-editable-in-portal") do |cust_edit|      
       cust_editable = cust_edit.text         
     end
     
     field_prop = Hash.new
     field_prop["display_name"] = title     
     field_prop["agent_rqrd"] = agent_closure
     field_prop["cust_rqrd"] = cust_rqrd
     field_prop["cust_visible"] = cust_visible
     field_prop["cust_editable"] = cust_editable
     
     label = title.gsub('?','')+"_"+current_account.id.to_s()
     label = label.gsub(/\s+/,"_")
     
     case field_type
       
     when "FieldCheckbox"
          type = "checkbox"         
          column_id = save_custom_field label , type , import_id
          field_prop["label"] = label
          field_prop["type"] = type
          unless column_id == -1
              update_form_customizer field_prop, column_id
          end
       
     when "FieldText"
          
          type = "text"
          column_id = save_custom_field label , type , import_id
          field_prop["label"] = label
          field_prop["type"] = type
          unless column_id == -1
              update_form_customizer field_prop, column_id  
          end
     when "FieldTagger"
          
          type = "dropdown"
          column_id = save_custom_field label , type , import_id
          
          choices = Array.new
          record.elements.each("custom-field-options/custom-field-option") do |options| 
            option_val =nil
            tag_val = []
            select_option = Hash.new
            options.elements.each("name") { |name| option_val =  name.text }  
            options.elements.each("value") { |value| tag_val =  value.text }   
            select_option["tags"]=tag_val
            select_option["value"]=option_val
            choices.push(select_option)
         end
          field_prop["type"] = type
          field_prop["label"] = label
          unless column_id == -1
              update_form_customizer field_prop, column_id,choices
          end
     when "FieldInteger"
          
          type = "number"
          column_id = save_custom_field label , type , import_id
          field_prop["type"] = type
          field_prop["label"] = label
          unless column_id == -1
              update_form_customizer field_prop, column_id  
          end
     when "FieldTextarea"
          
          type = "paragraph"
          column_id = save_custom_field label , type , import_id
          field_prop["type"] = type
          field_prop["label"] = label
          unless column_id == -1
              update_form_customizer field_prop, column_id
          end
     else
          logger.debug "None of the field type matches:: hope its a system field"
     end
       
     
    end
  
end


def import_forum_categories file_path
  
  created = 0
  updated = 0
  file = File.new(file_path) 
  doc = REXML::Document.new file
    
  REXML::XPath.each(doc,'//category') do |cat|    
    
     cat_name = nil
     cat_desc = nil
     import_id = nil     
     
     cat.elements.each("name") do |name|      
       cat_name = name.text         
     end
     
     cat.elements.each("description") do |desc|      
       cat_desc = desc.text         
     end
     
     cat.elements.each("id") do |imp_id|      
       import_id = imp_id.text         
     end
     
    @category = current_account.forum_categories.create(:name =>cat_name,:import_id => import_id.to_i(), :description =>cat_desc)
     
     
     
     #logger.debug " The user data:: name : #{usr_name} e_mail : #{usr_email} :: phone :: #{usr_phone} :: role :: #{usr_role} time_zone :: #{usr_time_zone} and usr_details :#{usr_details}"
 end
 
end

def import_file_attachment attach_url, base_dir, file_name  
  file_path = File.join(base_dir , file_name)
  open(file_path, "wb") {|file| file.write open(attach_url).read}
end

end

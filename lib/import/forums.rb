module Import::Forums
  
 def get_forum_data base_dir,make_solution
  
  created = 0
  updated = 0
  forum_import_count = Hash.new
  file_path = File.join(base_dir , "forums.xml")
  file = File.new(file_path) 
  doc = REXML::Document.new file
  
  default_category = current_account.forum_categories.find(:first , :order =>:id)
    
  REXML::XPath.each(doc,'//forum') do |forum|
    
     desc = nil
     name = nil
     forum_id = nil
     @category = nil
     import_id = nil
     forum_type = nil
     display_type = nil
     visibility_id = 1
     
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
     
     forum.elements.each("visibility-restriction-id") do |visibility|      
       visibility_id = visibility.text.to_i()        
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
     
     @forum = @category.forums.find_by_import_id(forum_id.to_i())
     @forum = @category.forums.find_by_name(name) if @forum.blank?
     if @forum.blank?
      @forum = @category.forums.new
      created=+1
     else
       updated=+1
     end
     
     @forum.account_id ||= current_account.id
     @forum.name = name
     @forum.description = desc
     @forum.import_id = forum_id.to_i()
     @forum.description_html = desc
     @forum.forum_type = forum_type
     @forum.forum_visibility = visibility_id
     
     if @forum.save      
        logger.debug "successfully saved the forum::"
     else    
        logger.debug "error while saving the forum:: #{@forum.errors.inspect}"
     end
 end
 logger.debug "forum import :created: #{created} and updated ::#{updated}"
 forum_import_count["created"]=created
 forum_import_count["updated"]=updated
 return forum_import_count
end


def make_solution_folder solution, base_dir
  
  cat_id = nil  
  folder_name = nil
  description = nil
  import_id = nil
  visibility_id = 1
  solution.elements.each("category-id") {|cat| cat_id = cat.text}
  solution.elements.each("name") {|folder| folder_name = folder.text}
  solution.elements.each("description") {|desc| description = desc.text}
  solution.elements.each("id") {|import| import_id  = import.text}
  solution.elements.each("visibility-restriction-id") {|visibility| visibility_id  = visibility.text.to_i()}
    
  @category = nil
  
  unless cat_id.blank?    
    @category = current_account.solution_categories.find_by_import_id(cat_id.to_i())    
    @category = add_solution_category(base_dir, cat_id) if @category.blank?
  else
    @category = current_account.solution_categories.find_or_create_by_name("General")  
  end
  logger.debug "@category is #{@category.inspect}"
  
  @folder = @category.folders.find_by_import_id(import_id.to_i())
  @folder = @category.folders.find_by_name(folder_name) if @folder.blank?  
  @folder = @category.folders.new if @folder.blank?
  @folder.name = folder_name
  @folder.description= description
  @folder.import_id = import_id
  @folder.visibility = visibility_id
  
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
    param = {:name =>cat_name,:import_id => import_id.to_i(), :description =>cat_desc}
    @category = current_account.solution_categories.find_by_name(cat_name)
    if @category.blank?
      @category = current_account.solution_categories.new(param)
       created+=1
    else
       updated+=1
    end
    
     
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
  
  created_count = 0
  updated_count = 0
  article_created = 0
  article_updated = 0
  topic_count = Hash.new
  @article_stat = Hash.new
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
     created_at = nil
     updated_at = nil
     
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
     
     entry.elements.each("created-at") do |created_time|  
        created_time = created_time.text
        created_at = created_time.to_datetime()
      end      
      entry.elements.each("updated-at") do |updated_time|  
        updated_at = updated_time.text
        updated_at = updated_at.to_datetime()
      end 
     
     entry.elements.each("flag-type-id") do |stamp|
       stamp_type = stamp.text.to_i() unless stamp.blank?
       stamp_type = 1 if stamp_type == 200
       stamp_type = 2 if stamp_type == 201
       stamp_type = 3 if stamp_type == 300       
     end
    
    @forum  = Forum.find_by_import_id_and_account_id(forum_id.to_i(), current_account.id)
    
    if (@forum.blank? && make_solution)
      logger.debug "The forum is blank and make_solu:: #{make_solution}"
      @sol_folder = current_account.folders.find_by_import_id(forum_id.to_i())
      @article = @sol_folder.articles.find_by_import_id(import_id) unless @sol_folder.blank?
      if @article.blank?
        article_created+=1
      else
        article_updated+=1
      end
      save_solution_article entry ,@sol_folder unless @sol_folder.blank?
      next
    end
    
    @topic = Topic.find_by_import_id_and_account_id(import_id, current_account.id)   
    if @topic.blank?
       @topic = @forum.topics.new
       created_count+=1
    else
      updated_count+=1
    end
    @topic.title = title
    @topic.import_id = import_id
    @topic.user_id = submitter_id
    @topic.account_id = current_account.id
    @topic.stamp_type = stamp_type
    @topic.created_at = created_at
    @topic.updated_at = updated_at
    topic_saved = @topic.save
    @post = @topic.posts.find_by_import_id(import_id)
    @post = @topic.posts.new if @post.blank?
    @post.body = body || title
    @post.account_id = current_account.id
    @post.body_html = body || title
    @post.forum_id = @forum.id
    @post.user_id = submitter_id
    @post.import_id = import_id
    @post.created_at = created_at
    @post.updated_at = updated_at
    
    if @post.save
      logger.debug "post saved successfully"
    else
      logger.debug "error while saving topic #{@post.errors.inspect}"
    end
   
    ## we may need to create the forum...first and then posts
     
    entry.elements.each("posts/post") do |post|
       
       post_body = nil
       created_by = nil
       imp_id = nil
       post_created_at = nil
       post_updated_at = nil
       
       post.elements.each("body") do |p_body|
         post_body = p_body.text
       end       
       post.elements.each("user-id") do |post_user|
         user = post_user.text         
         created_by = current_account.users.find_by_import_id(user.to_i()).id unless user.blank?
       end
       
       post.elements.each("id") do |imp|
         imp_id = imp.text
       end  
       
       post.elements.each("created-at") do |created|  
        post_created_time = created.text
        post_created_at = post_created_time.to_datetime()
       end 
     
       post.elements.each("updated-at") do |updated|  
        post_updated_at = updated.text
        post_updated_at = post_updated_at.to_datetime()
       end 
       
       @post = @topic.posts.find_by_import_id(imp_id.to_i())
       @post = @topic.posts.new if @post.blank?
       @post.body = post_body
       @post.account_id = current_account.id
       @post.body_html = post_body
       @post.forum_id = @forum.id
       @post.user_id = created_by
       @post.import_id = imp_id.to_i()
       @post.created_at = post_created_at
       @post.updated_at = post_updated_at
    
       if @post.save
          logger.debug "post saved successfully"
       else
          logger.debug "error while saving post #{@post.errors.inspect}"
       end
      
     end
     
  end
  @article_stat["created"] = article_created
  @article_stat["updated"]= article_updated
  topic_count["created"]=created_count
  topic_count["updated"]=updated_count
  return topic_count
end

def save_solution_article article, curr_folder
  
    title = nil
    desc = nil
    import_id = nil
    forum_id= nil
    submitter_id = nil
    is_public = true
    created = 0
    updated = 0 
    @article_stat = Hash.new
    created_at = nil
    updated_at = nil
    
     article.elements.each("body") {|body| desc = body.text }    
     article.elements.each("forum-id") { |forum|  forum_id = forum.text }   
     article.elements.each("is-public") {|public| is_public = public.text } 
     article.elements.each("submitter-id") do |submitter|      
       user = submitter.text 
       submitter_id = current_account.users.find_by_import_id(user.to_i()).id unless user.blank?
     end
     article.elements.each("created-at") do |created_time|  
        created_time = created_time.text
        created_at = created_time.to_datetime()
     end      
     article.elements.each("updated-at") do |updated_time|  
        updated_at = updated_time.text
        updated_at = updated_at.to_datetime()
     end 
   
    article.elements.each("title") { |forum_title| title = forum_title.text }     
    article.elements.each("id") { |import|  import_id = import.text }    
     
    @article= current_account.solution_articles.find_by_import_id(import_id.to_i())
    
    #return unless @article_exist.blank?
    if @article.blank?
      @article = curr_folder.articles.new
      created+=1
    else
      updated+=1
    end   
    
    @article.title = title
    @article.description = desc
    @article.import_id = import_id
    @article.user_id = submitter_id
    @article.title = title
    @article.desc_un_html = desc
    @article.account_id = current_account.id
    @article.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
    @article.art_type = Solution::Article::TYPE_KEYS_BY_TOKEN[:permanent]      
    @article.created_at = created_at
    @article.updated_at = updated_at
    
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


def import_forum_categories file_path
  
  created = 0
  updated = 0
  categ_imported = Hash.new
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
    
    params = {:name =>cat_name,:import_id => import_id.to_i(), :description =>cat_desc}
    @category = current_account.forum_categories.find_by_import_id(import_id.to_i())    
    @category = current_account.forum_categories.find_by_name(cat_name) if @category.blank?   
    
    unless @category.blank?
      if @category.update_attributes(params)
       updated+=1
      else
        logger.debug "Error while updating category :: #{@category.errors.inspect}"
      end
    else
      @category = current_account.forum_categories.new(params)
      if @category.save
        created+=1
      else
        logger.debug "@category saving has been failed :: #{@category.errors.inspect}"
      end
    end
   
     
 end
 
 categ_imported["created"]=created
 categ_imported["updated"]=updated
 return categ_imported
end


end
module Import::Forums
 def get_forum_data base_dir,make_solution
  
  created = 0
  updated = 0
  forum_import_count = Hash.new
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
       created=+1
     logger.debug "successfully saved the forum::"
     else     
      @forum = @category.forums.find_by_name(name)
      unless @forum.nil?
        updated=+1
        @forum.update_attribute(:import_id, forum_id.to_i())
      end
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
  topic_count = Hash.new
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
    
    if @post.save
     created=+1
    else
      logger.debug "error while saving topic"
    end
   
     
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
  logger.debug "forum entry import :created: #{created} "
  topic_count["created"]=created
  topic_count["updated"]=updated
  return topic_count
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
     
    @article_exist= current_account.solution_articles.find_by_import_id(import_id.to_i())
    
    return unless @article_exist.blank?
  
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
    
    @categ_existing = current_account.forum_categories.find_by_import_id(import_id.to_i())
    
    next unless @categ_existing.blank?
    created+=1
    @category = current_account.forum_categories.create(:name =>cat_name,:import_id => import_id.to_i(), :description =>cat_desc)
     
 end
 logger.debug "forum categ import :created: #{created} "
 categ_imported["created"]=created
end


end
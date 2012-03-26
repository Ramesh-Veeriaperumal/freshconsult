module Import::Zen::Forum
   
 class CategoryProp < Import::FdSax 
   element :name 
   element :description
   element :id , :as => :import_id
 end
 
 class ForumProp < Import::FdSax
   element :name 
   element :description
   element "display-type-id" , :as => :forum_type
   element "visibility-restriction-id" , :as => :forum_visibility
   element "category-id" , :as => :category_id
   element :id , :as => :import_id  
 end

  
 class Post < Import::FdSax 
   element :body
   element :id , :as => :import_id
   element "user-id" , :as => :user_id
   element "created-at" , :as => :created_at
   element "updated-at" , :as => :updated_at
 end

 class TopicProp < Import::FdSax 
   element :title 
   element :body
   element :id , :as => :import_id
   element "forum-id" , :as => :forum_id
   element "submitter-id" , :as => :user_id
   element "created-at" , :as => :created_at
   element "updated-at" , :as => :updated_at
   element "flag-type-id", :as => :stamp_type
   elements :post , :as =>:posts , :class => Post
 end
 

 
 def save_category category_xml
    category_prop = CategoryProp.parse(category_xml)
    category = @current_account.forum_categories.find(:first, :conditions =>['name=? or import_id=?',category_prop.name,category_prop.import_id])
    unless category
      category = @current_account.forum_categories.create(category_prop.to_hash)
    else
      category.update_attribute(:import_id , category_prop.import_id )
    end
 end
 
 
 
 def save_forum forum_xml
   forum_prop = ForumProp.parse(forum_xml)
   forum_type = forum_prop.forum_type.to_i()
   return save_solution_folder forum_prop if (forum_type == 1 && solution_import?)       
   category = @current_account.forum_categories.find_by_import_id(forum_prop.category_id) || @current_account.forum_categories.first
   forum = category.forums.find(:first, :conditions =>['name=? or import_id=?',forum_prop.name,forum_prop.import_id])
   unless forum
     forum_hash = forum_prop.to_hash.tap { |hs| hs.delete(:category_id) }
     forum = category.forums.build(forum_hash)
     forum.account_id = @current_account.id
     forum.save
   else
     forum.update_attribute(:import_id , forum_prop.import_id )
   end
 end

 
 def save_entry entry_xml
   topic_prop = TopicProp.parse(entry_xml)
   forum  = Forum.find_by_import_id_and_account_id(topic_prop.forum_id.to_i(), @current_account.id)
   return save_solution_article topic_prop if (forum.blank? && solution_import?)     
   topic = Topic.find_by_account_id_and_import_id(@current_account.id,topic_prop.import_id)   
   unless topic
       user = @current_account.all_users.find_by_import_id(topic_prop.user_id)
       topic_hash = topic_prop.to_hash.tap { |hs| hs.delete(:body) }.merge({:forum_id =>forum.id ,:user_id =>user.id })
       topic = forum.topics.build(topic_hash)
       topic.account_id = @current_account.id
       if topic.save
          post_hash = topic_prop.to_hash.delete_if{|k, v| [:title,:stamp_type].include? k }.merge({:forum_id =>forum.id ,:user_id =>user.id ,
                                                                                                     :body_html =>topic_prop.body })                                                                                        
          post = topic.posts.build(post_hash)
          post.account_id = @current_account.id
          post.save
       end
   else
       topic.update_attribute(:import_id , topic_prop.import_id )
   end
   #saving posts
   save_posts topic , topic_prop  
 end
 
 def save_posts topic,topic_prop   
   topic_prop.posts.each do |post_prop|
     user = @current_account.all_users.find_by_import_id(post_prop.user_id.to_i())
     post = topic.posts.find_by_import_id(post_prop.imp_id)     
     unless post
       user = @current_account.all_users.find_by_import_id(topic_prop.user_id)
       post_hash = post_prop.to_hash.merge({:user_id =>user.id ,:forum_id => topic.forum_id, :body_html =>post_prop.body})
       post = topic.posts.build(post_hash)
       post.account_id = @current_account.id
       post.save
     else
       post.update_attribute(:import_id , post_prop.import_id )
     end
   end   
 end

def save_solution_folder forum_prop
  category = @current_account.solution_categories.find_by_import_id(forum_prop.category_id)
  category =  @current_account.solution_categories.find_or_create_by_name("General") unless category
  folder = category.folders.find(:first, :conditions =>['name=? or import_id=?',forum_prop.name,forum_prop.import_id])
  unless folder
    folder_hash = forum_prop.to_hash.merge({:visibility => forum_prop.forum_visibility}).delete_if{|k, v| [:forum_type,:forum_visibility].include? k }
    folder = category.folders.create(folder_hash)
  else
    folder.update_attribute(:import_id , forum_prop.import_id )
  end  
end


def save_solution_article topic_prop 
  article= @current_account.solution_articles.find_by_import_id(topic_prop.import_id)
  unless article    
    sol_folder = @current_account.folders.find_by_import_id(topic_prop.forum_id)
    user = @current_account.all_users.find_by_import_id(topic_prop.user_id)
    article_hash = topic_prop.to_hash.delete_if{|k, v| [:body,:stamp_type,:forum_id].include? k }.merge({:user_id =>user.id ,
                                                                                               :description => topic_prop.body,
                                                                                               :status =>Solution::Article::STATUS_KEYS_BY_TOKEN[:published], 
                                                                                               :art_type => Solution::Article::TYPE_KEYS_BY_TOKEN[:permanent]})
    article = sol_folder.articles.build(article_hash)
    article.account_id = @current_account.id 
    article.save
  else
    article.update_attribute(:import_id , topic_prop.import_id )
  end
end
end
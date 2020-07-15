module Import::Zen::Forum
   
 URL_REGEX = /^http(?:s)?\:\/\//

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

  class Attachment < Import::FdSax
    element :url
  end
  
 class Post < Import::FdSax 
   element :body
   element :id , :as => :import_id
   element "user-id" , :as => :user_id
   element "created-at" , :as => :created_at
   element "updated-at" , :as => :updated_at
   element "forum-id", :as => :forum_id
   element "entry-id", :as => :entry_id
   elements :attachment , :as => :attachments , :class => Attachment
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
   elements :attachment , :as => :attachments , :class => Attachment
 end
 

 
 def save_category category_xml
    category_prop = CategoryProp.parse(category_xml)
    category = @current_account.forum_categories.find(:first, :conditions =>['name=? or import_id=?',category_prop.name,category_prop.import_id])
    unless category
      category = @current_account.forum_categories.create(category_prop.to_hash)
    else
      category.update_attribute(:import_id , category_prop.import_id )
    end
    save_solution_category
 end

 def save_solution_category
  category =  @current_account.solution_categories.find_by_name("General")
  Solution::Builder.category({:solution_category_meta => { :name=> "General" }}) unless category
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
       return unless user
       topic_hash = topic_prop.to_hash.tap { |hs| hs.delete(:body) }.merge({:forum_id =>forum.id ,:user_id =>user.id })
       topic = forum.topics.build(topic_hash)
       topic.account_id = @current_account.id
       forum_stamp_types = Topic::FORUM_TO_STAMP_TYPE[topic.forum.forum_type]
       topic.stamp_type = forum_stamp_types.fetch(topic.stamp_type, forum_stamp_types.first)
       if topic.save
          post_hash = topic_prop.to_hash.delete_if{|k, v| [:title,:stamp_type].include? k }.merge({
                                                                                                  :forum_id =>forum.id,
                                                                                                  :user_id =>user.id,
                                                                                                  :body_html => convert_inline_images(topic_prop.body) 
                                                                                                  })                                                                                        
          post = topic.posts.build(post_hash)
          post.account_id = @current_account.id
          post.save
          topic_prop.attachments.each do |attachment|   
              increment_key 'attachments_queued'
              Resque.enqueue( Import::Zen::ZendeskAttachmentImport,{:item_id => post.id, 
                                                                    :attachment_url => URI.encode(attachment.url), 
                                                                    :model => :post,
                                                                    :account_id => @current_account.id,
                                                                    :username => username,
                                                                    :password => password})
          end 
       end
   else
       topic.update_attribute(:import_id , topic_prop.import_id )
   end 
 end
 

#changed by me
 def save_post post_xml   
  post_prop = Post.parse(post_xml)
  topic = Topic.find_by_import_id_and_account_id(post_prop.entry_id, @current_account.id)
  if topic
    post = topic.posts.find_by_import_id(post_prop.import_id) 
    unless post
      user = @current_account.all_users.find_by_import_id(post_prop.user_id)
      return unless user
      post_hash = post_prop.to_hash.tap { |hs| hs.delete(:entry_id) }.merge({
                                                                            :user_id =>user.id,
                                                                            :forum_id => topic.forum_id,
                                                                            :body_html => convert_inline_images(post_prop.body) 
                                                                            })
      post = topic.posts.build(post_hash)
      post.account_id = @current_account.id
      post.save
    
      post_prop.attachments.each do |attachment|   
        increment_key 'attachments_queued'  
        Resque.enqueue( Import::Zen::ZendeskAttachmentImport,{:item_id => post.id, 
                                                              :attachment_url => URI.encode(attachment.url), 
                                                              :model => :post,
                                                              :account_id => @current_account.id,
                                                              :username => username,
                                                              :password => password})
      end 
    else
      post.update_attribute(:import_id , post_prop.import_id )
    end
  end 
 end


def save_solution_folder forum_prop  
  category = @current_account.solution_categories.find_by_name("General")
  if category
    category_meta = category.solution_category_meta
  else
    category_meta = Solution::Builder.category({
        :solution_category_meta => {
          :primary_category => {
            :name => "General"
          }
        }
      })
  end
  folder = category_meta.solution_folders.find(:first, :conditions =>['name=? or import_id=?',forum_prop.name,forum_prop.import_id])
  unless folder and folder.import_id.blank?
    folder_hash = forum_prop.to_hash.merge({
        :visibility => forum_prop.forum_visibility,
        :solution_category_meta_id => category_meta.id }).delete_if{|k, v| [:forum_type,:forum_visibility,:category_id].include? k }
    folder_hash[:primary_folder] = { 
      :name => "#{folder_hash[:name]} - #{folder_hash[:import_id]}",
      :import_id => folder_hash[:import_id]
    } if folder
    folder_meta = Solution::Builder.folder({ :solution_folder_meta => folder_hash })
    folder_meta.primary_folder
  else
    folder.update_attribute(:import_id , forum_prop.import_id )
  end  
end


def save_solution_article topic_prop 
  article= @current_account.solution_articles.find_by_import_id(topic_prop.import_id)
  unless article    
    sol_folder = @current_account.folders.find_by_import_id(topic_prop.forum_id)
    user = @current_account.all_users.find_by_import_id(topic_prop.user_id)
    return unless user
    article_hash = topic_prop.to_hash.delete_if{|k, v| [:body,:stamp_type,:forum_id].include? k }.merge({
                                                                                                :user_id =>user.id,
                                                                                                :description => convert_inline_images(topic_prop.body),
                                                                                                :status =>Solution::Article::STATUS_KEYS_BY_TOKEN[:published], 
                                                                                                :art_type => Solution::Article::TYPE_KEYS_BY_TOKEN[:permanent],
                                                                                                :solution_folder_meta_id => sol_folder.parent_id
                                                                                                })
    article_meta = Solution::Builder.article({ :solution_article_meta => article_hash })
    article = article_meta.primary_article

    topic_prop.attachments.each do |attachment|   
        increment_key 'attachments_queued'  
        Resque.enqueue( Import::Zen::ZendeskAttachmentImport,{:item_id => article.id, 
                                                              :attachment_url => URI.encode(attachment.url), 
                                                              :model => :article,
                                                              :account_id => @current_account.id,
                                                              :username => username,
                                                              :password => password})
    end 
  else
    article.update_attribute(:import_id , topic_prop.import_id )
  end
end

  def convert_inline_images  body
    return "-" if body.blank?
    desc_html = Nokogiri::HTML(CGI.unescapeHTML(body))
    desc_html.search('img').each do |img_tag|
      unless URL_REGEX.match img_tag['src']
        if img_tag['src'] && img_tag['src'].start_with?("/attachments")
          image_url = "#{params[:zendesk][:url]}#{img_tag['src']}"
          begin
            file = RemoteFile.new(image_url, username, password).fetch
            attachment = @current_account.attachments.build(
                                                          :content => file, 
                                                          :description => "public",
                                                          :attachable_type => "Image Upload", 
                                                          :account_id => @current_account.id
                                                          )
            attachment.save!
            img_tag['src'] = attachment.content.url
          rescue => e
            puts "Attachment exceed the limit!"
            NewRelic::Agent.notice_error(e)
          end
        end
      end
    end
    desc_html.to_s
  end

end
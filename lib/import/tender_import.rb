class Import::TenderImport < Struct.new(:params)
 
#  Usage: This file can be used to import from Tender
#  params: object_list eg: :ticket, :solution
#  eg:- param = {:path => "path_to_extracted_tender_dir" , 
#                :domain => "domain.freshdesk.com" ,:object_list =>[:ticket,:solution] }
#       tender = Import::TenderImport.new(param)
#       tender.perform
#   This is done for ordercup

 TENDER_TICKET_SOURCE = { :web=> Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:portal], 
                          :email=> Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email]
                        }
 OBJ_TO_PATH = {:ticket => "categories" , :solution => "sections"}

 def perform 
   path = params[:path] 
   object_list =params[:object_list] #can take from param[:ticket,:solution]
   @current_account = Account.find_by_full_domain(params[:domain])
   disable_notification 
   object_list.each do |obj|
     path = File.join(path, OBJ_TO_PATH[obj])
     send("read_data",path, obj)
   end  
   enable_notification
 end

def read_data(path, object ,name=nil )
    Dir.foreach(path) do |entry|
    next if (entry == '..' || entry == '.')
    full_path = File.join(path, entry)
    if File.directory?(full_path)
      read_data(full_path, object,entry)
    else
      begin
        send("save_#{object.to_s}", full_path) if File.extname(entry) == '.json'
      rescue => e
        puts "Unable to save object #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end
end

  # state - open, resolved
  # via = email,web
  #category is type - This can be passed as a param while running

def save_ticket ticket_file
  ticket = ActiveSupport::JSON.decode(File.read(ticket_file))
  ticket.symbolize_keys!
  import_exist = @current_account.tickets.find_by_import_id(ticket[:id])
  return unless  import_exist.blank?
  comments = ticket[:comments]
  first_comment = comments.first  
  first_comment.symbolize_keys!
  ticket_hash ={:subject => ticket[:title] ,:description => first_comment[:body] , :description_html => first_comment[:formatted_body],
                :requester => get_requester(ticket) , :status => Helpdesk::TicketStatus.status_keys_by_name(@current_account)[ticket[:state]] , 
                :source => TENDER_TICKET_SOURCE[ticket[:via].to_sym] , :import_id =>ticket[:id] , 
                :ticket_type => Helpdesk::Ticket::TYPE_KEYS_BY_TOKEN[:problem] , :created_at => ticket[:created_at].to_datetime()  }
   
  display_id_exist =  @current_account.tickets.find_by_display_id(ticket[:number])        
  ticket_hash.store(:display_id , ticket[:number]) unless display_id_exist
   
  ticket = @current_account.tickets.new(ticket_hash)
  if ticket.save
    comments.delete_at(0) unless comments.blank?
    comments.each do |comment|
      comment.symbolize_keys!
      create_notes_for_ticket ticket,comment 
    end
  else
    puts "unable to save ticket #{ticket.errors.inspect}"
  end  
end

def create_notes_for_ticket ticket,comment
    user = get_requester(comment)
    @note = ticket.notes.build({:incoming => user.customer?, :private => false, :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                                :user => user,   :account_id =>@current_account && @current_account.id,
                                :body =>comment[:body] , :body_html => comment[:formatted_body]   , :created_at => comment[:created_at].to_datetime()      
                              })
    unless @note.save
      puts "unable to save note: #{@note.errors.inspect}"
    end
end

def save_solution article_file
  article = ActiveSupport::JSON.decode(File.read(article_file))
  article.symbolize_keys!
  import_exist = @current_account.solution_articles.find_by_import_id(article[:id])
  return unless  import_exist.blank?  
  user = @current_account.users.find_by_user_role(4) 
  article_hash = {:user_id =>user.id , :title=> article[:title] , :description => article[:formatted_body], :status =>Solution::Article::STATUS_KEYS_BY_TOKEN[:published], 
                  :art_type => Solution::Article::TYPE_KEYS_BY_TOKEN[:permanent] , :import_id => article[:id] , :desc_un_html => article[:body],
                  :created_at => article[:created_at].to_datetime(), :updated_at =>article[:updated_at].to_datetime()}
  sol_folder = get_folder article_file,article[:section_id]   
  
  article = sol_folder.articles.build(article_hash)
  article.account_id = @current_account.id 
  unless article.save
    puts "unable to save article :#{article.errors.inspect}"
  end
end

def get_folder article_file , import_id
  category =  @current_account.solution_categories.find_or_create_by_name("Default Category")
  folder_name = File.split(File.dirname(article_file))[1]
  folder = category.folders.find(:first, :conditions =>['name=? or import_id=?',folder_name, import_id])
  unless folder
      folder_hash = {:name => folder_name , :import_id => import_id, :visibility => Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone] }
      folder = category.folders.create(folder_hash)
  else
     folder.update_attribute(:import_id , import_id )
  end
  return folder
end

def get_requester ticket
 email = ticket[:author_email]
 user = @current_account.all_users.find_by_email(email) 
 if user.blank?
    usr_role = 3
    user_params = {:user => {:name =>  ticket[:author_name], :email => email , :job_title => "" , :user_role => usr_role ,:time_zone =>@current_account.time_zone }}
    user = @current_account.users.new
    if user.signup!(user_params)      
       @agent = Agent.create(:user_id =>user.id ) unless (usr_role == 3)
    end
 end
  return user
end

  def disable_notification    
     Thread.current["notifications_#{@current_account.id}"] = EmailNotification::DISABLE_NOTIFICATION   
  end
  
  def enable_notification
    Thread.current["notifications_#{@current_account.id}"] = nil
  end

end



class Import::ZendeskData < Struct.new(:params)
   require 'rexml/document'    
   require 'rexml/xpath'   
   require 'zip/zip'
   require 'fileutils'
    
    include Import::CustomField
    include Import::Forums
    
    ZENDESK_TICKET_TYPES = {0 => "No Type Set", 
                            1 => "Question",
                            2 => "Incident",
                            3 => "Problem",
                            4 => "Task"}
    ZENDESK_TICKET_STATUS = {1 => 2, 
                             2=> 3,
                             3=> 4,
                             4 =>5
                            }
                            
   ZENDESK_ROLE_MAP = {0 =>3,
                       4 => 2,
                       2 => 1
                      }
                          
  
  def perform

    @current_account = Account.find_by_full_domain(params[:domain])
    file_list = params[:zendesk][:files]
    
    begin
        base_dir = extract_zendesk_zip
        disable_notification 
        handle_migration(file_list , base_dir)
        enable_notification
        send_success_email(params[:email] , params[:domain])
        delete_import_files base_dir
    rescue
       enable_notification
       handle_error
       puts "Unable to connect ::rescue"
       return true
    end
      
  end
 
  
  def handle_migration (file_list , base_dir)
    create_solution = false
    user_activation_email = false
    
    import_list = file_list.reject(&:blank?)  
    
    @customers_stat = Hash.new
    @users_stat = Hash.new
    @groups_stat = Hash.new
    @tickets_stat = Hash.new
    
    if import_list.include?("solution")
       create_solution = true
    end 
    
    if import_list.include?("user_notify")
       puts "user_notify is enabled"
       user_activation_email = true   
    end    
    
    if import_list.include?("customers")
       Thread.current["notifications_#{@current_account.id}"][EmailNotification::USER_ACTIVATION][:requester_notification] = user_activation_email       
       @customers_stat = handle_customer_import base_dir
       @users_stat = handle_user_import base_dir  
    end
    if import_list.include?("tickets")
       import_flexifields(base_dir, @current_account)
       @groups_stat = handle_group_import base_dir
       @tickets_stat = handle_ticket_import base_dir       
    end
    if import_list.include?("forums")
       handle_forums_import base_dir , create_solution
    end  

  end


  def disable_notification    
     Thread.current["notifications_#{@current_account.id}"] = EmailNotification::DISABLE_NOTIFICATION   
  end
  
  def enable_notification
    Thread.current["notifications_#{@current_account.id}"] = nil
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
     @customer = @current_account.customers.find_by_import_id(import_id.to_i())
     unless @customer.blank?
        if @customer.update_attributes(params)
             updated+=1
        end      
     else
        @customer = @current_account.customers.new(params)
        if @customer.save
            created+=1
            puts "Customer has been saved with name:: #{cust_name}"
        else
            puts "Save customer has been failed:: #{@customer.errors.inspect}"
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
    
     grp_name = group.elements["name"].text
     grp_id = group.elements["id"].text
       
     params = {:name =>grp_name, :import_id =>grp_id}
     @group = @current_account.groups.find_by_import_id(grp_id.to_i())
     @group = @current_account.groups.find_by_name(grp_name) if @group.blank?
     unless @group.blank?
        if @group.update_attributes(params)
             updated+=1
        end      
     else
        @group = @current_account.groups.new(params)
        if @group.save
            created+=1
            puts "Group has been saved with name:: #{grp_name}"
        else
            puts "Save group has been failed:: #{@group.errors.inspect}"
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
    
     usr_role = 3
     usr_name =  user.elements["name"].text
     usr_email = user.elements["email"].text
     usr_phone = user.elements["phone"].text
     zen_usr_role = user.elements["roles"].text
     role_id = zen_usr_role.to_i()
     usr_time_zone = user.elements["time-zone"].text
     usr_details = user.elements["details"].text 
     import_id = user.elements["id"].text
     created_at = nil
     
     usr_role = ZENDESK_ROLE_MAP[role_id]
          
     cust_id = user.elements["organization-id"].text 
     customer = @current_account.customers.find_by_import_id(cust_id) 
     org_id = customer.id unless customer.blank?
   
     
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
      @user= @current_account.all_users.find_by_email(usr_email)    
     end
     @user = @current_account.all_users.find_by_import_id(import_id) if @user.blank?     
     puts "email is :: #{usr_email} and import id :: #{import_id} and \n user: #{@user.inspect}"
     unless @user.blank?
          if @user.update_attribute(:import_id , import_id )
             updated+=1
              if usr_role != 3               
               @agent = Agent.find_or_create_by_user_id(@user.id )
           end
         else
            puts "updation of the user has been failed :: #{@user.errors.inspect}"
          end
     else
          @user = @current_account.users.new
          @user.time_zone = usr_time_zone
          if usr_email.blank?
              puts "Import id is :: #{import_id}"
             #puts "email is blank:: #{@user.inspect}"
             @user.deleted=true
             @params_hash[:user][:user_role] = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
             puts  "after ::email is blank:: #{@user.inspect} is del: #{@user.deleted}"             
          end
          #@params_hash[:user][:user_role] = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
          if @user.signup!(@params_hash) 
            puts "user has been save #{@user.inspect}"
            created+=1
            if usr_role != 3
               puts "Its an agents and the user_id is :: #{@user.id}"
               @agent = Agent.create(:user_id =>@user.id )
            end
          else
            puts "unable to create the user :: #{@user.errors.inspect}" 
          end
        
      end     
     puts " The user data:: name : #{usr_name} e_mail : #{usr_email} :: phone :: #{usr_phone} :: role :: #{usr_role} time_zone :: #{usr_time_zone} and usr_details :#{usr_details}"

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
        
      sub = req.elements["subject"].text 
      desc = req.elements["description"].text 
      display_id = req.elements["nice-id"].text  
      tags= req.elements["current-tags"].text
      due_date = req.elements["due-date"].text   
      resolution_time= req.elements["resolution-time"].text 
      import_id = nil
        
      assign_id = req.elements["assignee-id"].text
      assignee = @current_account.all_users.find_by_import_id(assign_id.to_i()) unless assign_id.blank? 
        
      req_id = req.elements["requester-id"].text
      requester = @current_account.all_users.find_by_import_id(req_id.to_i())  unless req_id.blank?
   
            
      status = req.elements["status-id"].text
      stat_id = status.to_i() unless status.blank?
      status_id = ZENDESK_TICKET_STATUS[stat_id]
     
      priority = req.elements["priority-id"].text
      priority_id = priority.to_i() unless priority.blank?
      priority_id = 1 if priority_id < 1
      
      ticket_type_id = req.elements["ticket-type-id"].text
      ticket_type = ZENDESK_TICKET_TYPES[ticket_type_id.to_i]
      
      imp_id = req.elements["group-id"].text
      group_id = @current_account.groups.find_by_import_id(imp_id.to_i()).id unless imp_id.blank?
     
      created_time =  req.elements["created-at"].text
      created_at = created_time.to_datetime()
   
      updated_at = req.elements["updated-at"].text
      updated_at = updated_at.to_datetime()
     
      @request = @current_account.tickets.find_by_import_id(display_id.to_i())    
     
      if @request.blank?
        @request = @current_account.tickets.new 
        created_count+=1
      else
        updated_count+=1
        next
      end
      
      @display_id_exist = @current_account.tickets.find_by_display_id(display_id.to_i())
      
      @request.subject = sub || 'no subject'
      @request.description = desc
      @request.requester = requester
      @request.responder = assignee if (assignee && !assignee.customer?)
      @request.group_id = group_id
      @request.display_id = display_id if @display_id_exist.blank?
      @request.import_id = display_id
      @request.status = status_id
      @request.priority = priority_id
      @request.ticket_type = ticket_type
      @request.created_at = created_at
      @request.updated_at = updated_at
      

      if @request.save         
        puts "successfully saved"
      else
        puts "failed to save the ticket :: #{@request.errors.inspect}"
      end
      
      ## Create attachemnts

      req.elements.each("attachments/attachment") do |attach|         
        attachemnt_url = nil        
        attach.elements.each("url") {|attach_url|   attachemnt_url = attach_url.text  } 
        Import::Attachment.new(@request.id ,attachemnt_url, :ticket )
       
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
       #puts "post :: #{post.inspect}"
       
       comment.elements.each("value") { |val| note_body =  val.text } 
       comment.elements.each("is-public") { |public| is_public =  public.text } 
       comment.elements.each("created-at") { |created_time| note_created_time =  created_time.text } 
       
       comment.elements.each("author-id") do |author|
          author_id = author.text
          note_created = @current_account.all_users.find_by_import_id(author_id.to_i())              
          note_created_by = note_created.id unless note_created.blank?            
          incoming = true if note_created.customer?
       end
       
        @note = @request.notes.build({
        :incoming => incoming,
        :private => is_public,
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
        :user_id => note_created_by,
        :account_id =>@current_account && @current_account.id,
        :body =>note_body        
        })
         @note.created_at = note_created_time.to_datetime()
         if @note.save
           puts "successfully saved"
         else
            puts "failed to save the note :: #{@note.errors.inspect}"
         end
        
        ##adding attachment to notes
        comment.elements.each("attachments/attachment") do |attach| 
        
        attachemnt_url = nil        
        attach.elements.each("url") {|attach_url|   attachemnt_url = attach_url.text  } 
        Import::Attachment.new(@note ,attachemnt_url , :note )
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
  
  puts "Here its :: handle_account_import"
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

def extract_zendesk_zip
  
    puts "extract_sen_zip :: curr time:: #{Time.now}"
  
    file=  @current_account.data_import.attachments.first.content.to_file
    
    @upload_file_name = file.original_filename
    
    puts "@upload_file_name:: #{@upload_file_name}"
    
    zip_file_name = "#{RAILS_ROOT}/public/files/#{@upload_file_name}"
    File.open(zip_file_name , "wb") do |f|
      f.write(file.read)
    end
    
    @file_list = Array.new   
    
    @out_dir = "#{RAILS_ROOT}/public/files/temp/#{@upload_file_name.gsub('.zip','')}"
    FileUtils.mkdir_p @out_dir    
    zf = Zip::ZipFile.open(zip_file_name)
    
    zf.each do |zip_file|        
      report_name = File.basename(zip_file.name).gsub('zip','xml')
      fpath = File.join(@out_dir , report_name)    
      
      if(File.exists?(fpath))
        FileUtils.rm_f(fpath)
      end
      zf.extract(zip_file, fpath)
      file_det = Hash.new
      file_det["file_name"] = report_name
      file_det["file_path"] = fpath
      @file_list.push(file_det)
    end    
    import_files_from_zendesk @out_dir  
    puts "after the import_files_from_zendesk"
    delete_zip_file
    return @out_dir
end


def delete_zip_file
    zip_file_name = "#{RAILS_ROOT}/public/files/#{@upload_file_name}"
    FileUtils.rm_rf zip_file_name
  end
  def import_files_from_zendesk base_dir      
    file_arr = Array.new       
    file_arr.push("categories.xml")
    file_arr.push("ticket_fields.xml")
    
    import_file base_dir,file_arr     
  end

 
def import_file base_dir, file_arr
  
  zendesk_url = params[:zendesk][:url]
  usr_name = params[:zendesk][:user_name]
  usr_pwd = params[:zendesk][:user_pwd]  
  
  zendesk_url = zendesk_url+'/' unless zendesk_url.ends_with?('/')
  
  file_arr.each do |file_name|
    
    url = zendesk_url+file_name
    file_path = File.join(base_dir , file_name)      
    url = URI.parse(url)  
    req = Net::HTTP::Get.new(url.path)  
    req.basic_auth usr_name, usr_pwd
    res = Net::HTTP.start(url.host, url.port) {|http| http.request(req) }     
    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
       File.open(file_path, 'w') {|f| f.write(res.body) }      
    else 
      raise ArgumentError, "Unable to connect zendesk" 
    end
  end
  
end

def handle_error
     delete_zip_file
     email_params = {:email => params[:email], :domain => params[:domain]}
     Admin::DataImportMailer.deliver_import_error_email(email_params)
     FileUtils.remove_dir(@out_dir,true)  
     @current_account.data_import.destroy
    
end

 
  def send_success_email (email,domain)
    email_params = {:email => email, :domain => domain, 
                     :tickets_stat =>  @tickets_stat ,:groups_stat => @groups_stat,
                     :users_stat => @users_stat , :customers_stat => @customers_stat , 
                     :topic_stat => @topic_stat,:article_stat => @article_stat}
     Admin::DataImportMailer.deliver_import_email(email_params)
  end
 
  
  def delete_import_files base_dir
    FileUtils.remove_dir(base_dir,true)  
    @current_account.data_import.destroy
  end


end
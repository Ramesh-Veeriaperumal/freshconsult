class Social::FacebookMessage
  
 def initialize(fb_page  , options = {} )
    fb_page = Account.first.facebook_pages.first
    @account = options[:current_account]  || fb_page.account
    @rest = Koala::Facebook::GraphAndRestAPI.new(fb_page.page_token)
    @fb_page = fb_page
 end
 
 def fetch
   threads = @rest.get_connections('me','conversations',{:since => @fb_page.message_since})  
   updated_time = threads.collect {|f| f["updated_time"]}.compact.max
   create_ticket_from_threads threads               
   @fb_page.update_attribute(:message_since, Time.parse(updated_time).to_i) unless updated_time.blank?
 end
 
def create_ticket_from_threads threads
      threads.each do |thread|
        thread.symbolize_keys! 
        puts "Thread id is :#{thread[:id]}"
        fb_msg = @account.facebook_posts.latest_thread(thread[:id] , 1) ##latest thread
        puts "fb message:#{fb_msg.inspect}"
        previous_ticket = fb_msg.first.postable unless fb_msg.blank?       
        last_reply = (!previous_ticket.notes.blank? && !previous_ticket.notes.latest_facebook_message.blank?) ? previous_ticket.notes.latest_facebook_message.first : previous_ticket  unless previous_ticket.blank?
        puts "last reply: #{last_reply}"
        if last_reply && (Time.zone.now < (last_reply.created_at + @fb_page.dm_thread_time.seconds)) 
            add_message_as_note thread  , previous_ticket
        else
            add_message_as_ticket thread 
        end
     end
end

def add_message_as_note thread, ticket
  thread_id = thread[:id]
  messages = thread[:messages].symbolize_keys! 
    messages[:data].each do |message|
      message.symbolize_keys!
      user = get_facebook_user(message[:from])
      @note = ticket.notes.build(
                        :body => message[:message],
                        :private => true ,
                        :incoming => true,
                        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"],
                        :account_id => @fb_page.account_id,
                        :user => user,
                        :created_at => Time.zone.parse(message[:created_time]),
                        :fb_post_attributes => {:post_id => message[:id], :facebook_page_id =>@fb_page.id ,:account_id => @account.id , 
                                                :msg_type =>'dm' ,:thread_id => thread_id}
                                  )
      unless @note.save
        puts "error while saving the note #{@note.errors.to_json}"
      end
    end
end

def add_message_as_ticket thread
  puts "add_message_as_ticket :thread#{thread.inspect}"
  group_id = @fb_page.product.group_id unless @fb_page.product.blank?
  messages = thread[:messages].symbolize_keys!
  messages = get_new_data_set messages
  puts "add_message_as_ticket new data set#{messages.inspect}"
  message = messages.last #Need to check last is giving the first message/or we need to find the least created date
  return unless message
  message.symbolize_keys!
  requester = get_facebook_user(message[:from])
  @ticket = @account.tickets.build(
          :subject => truncate_subject(message[:message], 100),
          :description => message[:message],
          :description_html => message[:message],
          :requester => requester,
          :email_config_id => @fb_page.product_id,
          :group_id => group_id,
          :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook],
          :created_at => Time.zone.parse(message[:created_time]),
          :fb_post_attributes => {:post_id => message[:id], :facebook_page_id =>@fb_page.id ,:account_id => @account.id ,
                                  :msg_type =>'dm' ,:thread_id =>thread[:id]} )
      
   if @ticket.save
      if messages.size > 1
         add_message_as_note thread , @ticket
      end
   else
      puts "error while saving the ticket:: #{@ticket.errors.to_json}"    
   end
end

def get_new_data_set data_set
    message_id_arr = data_set[:data].collect{|x| x["id"]}
    existing_msg_arr = @account.facebook_posts.find(:all,:select =>:post_id ,:conditions =>{:post_id =>message_id_arr}).collect{|a|a.post_id} 
    return data_set[:data].reject{|d| existing_msg_arr.include? d["id"]}    
end

  def get_facebook_user(profile)
    profile.symbolize_keys!
    user = @account.all_users.find_by_fb_profile_id(profile[:id])
    unless user
      user = @account.contacts.new
      if user.signup!({:user => {:fb_profile_id => profile[:id], :name => profile[:name], 
                    :active => true,
                    :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}})
      else
          puts "unable to save the contact:: #{user.errors.inspect}"
      end   
    end
     user
  end
  
  
  def truncate_subject(subject , count)
    puts "truncate subject #{subject}"
    (subject.length > count) ? "#{subject[0..(count - 1)]}..." : subject
  end
    
 
end
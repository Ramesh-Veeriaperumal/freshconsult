
class Import::Zen::Start < Struct.new(:params)

    include Import::Zen::FlexiField
    include Import::Zen::Forum
    include Import::Zen::Ticket
    include Import::Zen::User
    include Import::Zen::FileUtil
    include Import::Zen::Group
    include Import::Zen::Organization
    
    OBJECT_FILE_MAP = {:organization => "organizations.xml" ,:user => "users.xml" , :group => "groups.xml" ,:ticket => "tickets.xml" ,
                       :record => "ticket_fields.xml"  , :category => "categories.xml",:forum => "forums.xml"  , :entry=>"entries.xml" }
    SUB_FUNCTION_MAP = {:customers =>[:organization, :user] , :tickets =>[:group , :record, :ticket] , :forums => [:category,:forum,:entry] }
 
  
  def perform
    @current_account = Account.find_by_full_domain(params[:domain])   
    @current_account.make_current    
    return if @current_account.blank?
    #begin
      @base_dir = extract_zendesk_zip
      disable_notification 
      handle_migration(params[:zendesk][:files] , @base_dir)
      enable_notification
      send_success_email(params[:email] , params[:domain])
      delete_import_files @base_dir
#    rescue => e
#      handle_error
#      NewRelic::Agent.notice_error(e)
#      puts "Error while importing data ::#{e.message}\n#{e.backtrace.join("\n")}"
#      return true   
#    end
  end
   
 def handle_migration (file_list , base_dir)
    import_list = file_list.reject(&:blank?)  
    import_list = import_list.unshift("customers").uniq
    import_list.each do |object|
       SUB_FUNCTION_MAP[object.to_sym].each do |func|
            send('read_data',func.to_s) 
       end
    end
 end
 
def read_data(obj_node)
    file_path = File.join(@base_dir , OBJECT_FILE_MAP[obj_node.to_sym])
    reader = Nokogiri::XML::Reader(File.open(file_path))
    while reader.read
     begin
       if reader.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT and reader.name == obj_node
          send("save_#{obj_node}" , reader.outer_xml)
       end
     rescue => err
       puts "Error while reading ::#{err.message}\n#{err.backtrace.join("\n")}"
     end
   end
end

private
 
  def disable_notification        
     Thread.current["notifications_#{@current_account.id}"] = EmailNotification::DISABLE_NOTIFICATION   
     Thread.current["notifications_#{@current_account.id}"][EmailNotification::USER_ACTIVATION][:requester_notification] = params[:zendesk][:files].include?("user_notify")   
  end
  
  def enable_notification
    Thread.current["notifications_#{@current_account.id}"] = nil
  end

  def solution_import?
    params[:zendesk][:files].include?("solution")
  end

end
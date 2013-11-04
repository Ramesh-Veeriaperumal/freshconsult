
class Import::Zen::Start < Struct.new(:params)

    include Import::Zen::FlexiField
    include Import::Zen::Forum
    include Import::Zen::Ticket
    include Import::Zen::User
    include Import::Zen::FileUtil
    include Import::Zen::Group
    include Import::Zen::Organization
    include Helpdesk::ToggleEmailNotification
    
    OBJECT_FILE_MAP = {:organization => "organizations.xml" ,:user => "users.xml" , :group => "groups.xml" ,:ticket => "tickets.xml" ,
                       :record => "ticket_fields.xml"  , :category => "categories.xml",:forum => "forums.xml"  , :entry=>"entries.xml", :post=>"posts.xml" }
    SUB_FUNCTION_MAP = {:customers =>[:organization, :user] , :tickets =>[:group , :record, :ticket] , :forums => [:category,:forum,:entry,:post] }
 
  
  attr_accessor :params, :username, :password

  def initialize(params={})
    params.symbolize_keys!
    params[:zendesk].symbolize_keys! if params[:zendesk]
    self.params = params
    self.username = params[:zendesk][:user_name]
    self.password = params[:zendesk][:user_pwd]
  end

  def perform
    @current_account = Account.current  
    return if @current_account.blank?
    begin
      @base_dir = extract_zendesk_zip(params[:zendesk][:file_url], username, password)
      disable_notification(@current_account)
      handle_migration(params[:zendesk][:files] , @base_dir)
      enable_notification(@current_account)
      send_success_email(params[:email] , params[:domain])
      delete_import_files @base_dir
    rescue => e
      NewRelic::Agent.notice_error(e)
      puts "Error while importing data ::#{e.message}\n#{e.backtrace.join("\n")}"
      handle_error
      return true   
    ensure
      @current_account.zendesk_import.destroy 
    end
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
  begin
    reader = Nokogiri::XML::Reader(File.open(file_path))
    while reader.read
       if reader.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT and reader.name == obj_node
          if obj_node.eql?("ticket")
              Resque.enqueue( Import::Zen::ZendeskTicketImport , { :ticket_xml => reader.outer_xml, 
                                                                   :account_id => @current_account.id,
                                                                   :username => username,
                                                                   :password => password})
          else
            send("save_#{obj_node}" , reader.outer_xml)
          end
       end
    end
  rescue Errno::ENOENT
    handle_format_error
    exit
  rescue => err
    NewRelic::Agent.notice_error(err)
    puts "Error while reading ::#{err.message}\n#{err.backtrace.join("\n")}"
  end
end

private

  def solution_import?
    params[:zendesk][:files].include?("solution")
  end

end
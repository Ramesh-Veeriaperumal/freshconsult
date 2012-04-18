module Import::Zen::FileUtil
  
def extract_zendesk_zip    
    puts "extract_zen_zip :: curr time:: #{Time.now}"  
    file=  @current_account.data_import.attachments.first.content.to_file    
    @upload_file_name = file.original_filename
    zip_file_name = "#{RAILS_ROOT}/public/files/#{@upload_file_name}"
    File.open(zip_file_name , "wb") do |f|
      f.write(file.read)
    end    
    @file_list = Array.new       
    @out_dir = "#{RAILS_ROOT}/public/files/extract/#{@upload_file_name.gsub('.zip','')}"
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
    req = Net::HTTP::Get.new(url.request_uri)  
    req.basic_auth usr_name, usr_pwd
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true if url.scheme == 'https'
    res = http.start{|http| http.request(req) }     
    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
       File.open(file_path, 'w') {|f| f.write(res.body) }      
    else 
      raise ArgumentError, "Unable to connect zendesk" 
    end
  end
  
end

def handle_error
     enable_notification
     delete_zip_file
     email_params = {:email => params[:email], :domain => params[:domain]}
     Admin::DataImportMailer.deliver_import_error_email(email_params)
     FileUtils.remove_dir(@out_dir,true)  
     @current_account.data_import.destroy   
end
 
def send_success_email (email,domain)
    puts "sending success email"
    email_params = {:email => email, :domain => domain}
    Admin::DataImportMailer.deliver_import_email(email_params)
end
   
def delete_import_files base_dir
    FileUtils.remove_dir(base_dir,true)  
    @current_account.data_import.destroy
end
  
end
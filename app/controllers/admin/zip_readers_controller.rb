class Admin::ZipReadersController < Admin::AdminController
  
before_filter { |c| c.requires_permission :manage_tickets }  

require 'zip/zip'
require 'fileutils'

  def index
    
  end
  
  def extract_zip        
    
    file=params[:dump][:file]    
    @upload_file_name = file.original_filename
    
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
        File.delete(fpath)
      end
      zf.extract(zip_file, fpath)
      file_det = Hash.new
      file_det["file_name"] = report_name
      file_det["file_path"] = fpath
      @file_list.push(file_det)
    end    
    import_files_from_zendesk @out_dir    
    delete_zip_file
    
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
  
  zendesk_url = params[:dump][:url]
  usr_name = params[:dump][:user_name]
  usr_pwd = params[:dump][:user_pwd]  
  
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
      flash[:notice] = "Unable to contact zendesk . Please verify your zendesk credentials and try again !!" 
      delete_zip_file      
      return redirect_to :back     
    end
  end
  
end

end

class ZipReadersController < ApplicationController 

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
    
  end
  
  def import_files_from_zendesk base_dir
    
    zendesk_uri = params[:dump][:url]
    usr_name = params[:dump][:user_name]
    usr_pwd = params[:dump][:user_pwd]
    
    #categories
    
    url = zendesk_uri+'/categories.xml'
    file_path = File.join(base_dir , "categories.xml")   
    import_file url,file_path , usr_name,usr_pwd
    
    #ticket_fields
    url = zendesk_uri+'/ticket_fields.xml'
    file_path = File.join(base_dir , "ticket_fields.xml")   
    import_file url,file_path, usr_name , usr_pwd
    
  end

 
def import_file url, file_path, usr_name , usr_pwd
  
  ##need to remove this once everything is done
  usr_name = "uknowmewell@gmail.com"
  usr_pwd = "Opmanager123$"
  
  url = URI.parse(url)  
  req = Net::HTTP::Get.new(url.path)  
  req.basic_auth usr_name, usr_pwd
  res = Net::HTTP.start(url.host, url.port) {|http| http.request(req) }     
  File.open(file_path, 'w') {|f| f.write(res.body) }
  logger.debug "successfully imported files from zendesk with file_path:: #{file_path.inspect}"
end


end

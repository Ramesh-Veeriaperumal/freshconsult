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
    
  end

end

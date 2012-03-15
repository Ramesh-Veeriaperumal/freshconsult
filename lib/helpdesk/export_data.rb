require "tempfile"
require 'zip/zip'
require 'zip/zipfilesystem'
require 'fileutils'

class Helpdesk::ExportData < Struct.new(:params)
  
  def perform
    @current_account = Account.find_by_full_domain(params[:domain])
    @data_export = @current_account.data_export   
    
    @out_dir = "#{RAILS_ROOT}/tmp/#{@current_account.id}" 
    zip_file_path = File.join("#{RAILS_ROOT}/tmp/","#{@current_account.id}.zip") 
    
    delete_zip_file zip_file_path #cleaning up the directory
    FileUtils.mkdir_p @out_dir
    
    export_forums_data  #Forums data
    export_solutions_data #Solutions data
    export_users_data #Users data
    export_customers_data #Companies data
    export_tickets_data #Tickets data
    zip_all_files zip_file_path
    
    @file = File.open(zip_file_path,  'r')
    
    if @data_export.attachment.nil?
      @data_export.build_attachment(:content => @file,  :account_id => @current_account.id)
    else
      @data_export.attachment.update_attributes(:content => @file)
    end
    @data_export.save!
    url =  @data_export.attachment.content.url
    update_export_status
    DataExportMailer.deliver_export_email({:email => params[:email], :domain => params[:domain], :url =>  url})
    delete_zip_file zip_file_path  #cleaning up the directory
    
  end
  
  def delete_zip_file(zip_file_path)
    # Delete the Zip file and the Directory if exists
    if(File.exists?(@out_dir))
        FileUtils.remove_dir(@out_dir,true)
        FileUtils.rm_f(zip_file_path)
    end
    
  end
  
  
  
  def update_export_status
    @data_export.status = false
    @data_export.save!
  end
  
  def zip_all_files(zip_file_path) 
    Zip::ZipFile.open(zip_file_path, Zip::ZipFile::CREATE) do |zipfile|
      file_list = Dir.glob(@out_dir+"/*")
      file_list.each do |file|
        zipfile.add(File.basename(file),file)
      end
    end
    
  end

   def export_forums_data
     forum_categories = @current_account.forum_categories.all
     xml_output = forum_categories.to_xml(:include => {:forums => {:include => {:topics => {:include => :posts} }  }})
     write_to_file("Forums.xml",xml_output)
  end
  
  def export_solutions_data
     solution_categories = @current_account.solution_categories.all  
     xml_output = solution_categories.to_xml(:include => {:folders => {:include => :articles  }})
     write_to_file("Solutions.xml",xml_output)
  end
  
  def export_users_data
     users = @current_account.users.all  
     xml_output = users.to_xml(:except => [:crypted_password,:password_salt,:persistence_token,:single_access_token,:perishable_token]) 
     write_to_file("Users.xml",xml_output)
  end
  
  def export_customers_data
     customers = @current_account.customers.all  
     xml_output = customers.to_xml
     write_to_file("Customers.xml",xml_output)
  end
  
   def export_tickets_data
     tickets = @current_account.tickets.all
     xml_output = tickets.to_xml
     write_to_file("Tickets.xml",xml_output)
  end
  
  def export_groups_data
    groups = @current_account.groups.all
    xml_output = groups.to_xml(:include => :agent_groups)
    write_to_file("Groups.xml",xml_output)
  end
  
  def write_to_file(filename,res_data)
    file_path = File.join(@out_dir , filename) 
    File.open(file_path, 'w') {|f| f.write(res_data) }
  end
  
end
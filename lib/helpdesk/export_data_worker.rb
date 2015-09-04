require "tempfile"
require 'zip/zip'
require 'zip/zipfilesystem'
require 'fileutils'

class Helpdesk::ExportDataWorker < Struct.new(:params)

  def perform
    begin
      @current_account = Account.find_by_full_domain(params[:domain])
      @current_account.make_current
      @data_export = @current_account.data_exports.data_backup[0]   
      @data_export.started!
      @out_dir = "#{Rails.root}/tmp/#{@current_account.id}" 
      zip_file_path = File.join("#{Rails.root}/tmp/","#{@current_account.id}.zip") 
      
      delete_zip_file zip_file_path #cleaning up the directory
      FileUtils.mkdir_p @out_dir

      export_data #method overwritten in itil

      zip_all_files zip_file_path
      @data_export.file_created!
      @file = File.open(zip_file_path,  'r')
      
      @data_export.build_attachment(:content => @file)
      @data_export.save!

      @data_export.file_uploaded!
      hash_file_name = Digest::SHA1.hexdigest(@data_export.id.to_s + Time.now.to_f.to_s)
      @data_export.save_hash!(hash_file_name)
      url = Rails.application.routes.url_helpers.download_file_url(@data_export.source,hash_file_name, 
                    :host => @current_account.host, 
                    :protocol => 'https')
      DataExportMailer.data_backup({:email => params[:email], 
                                            :domain => params[:domain],
                                            :host => @current_account.host,
                                            :url =>  url})
      delete_zip_file zip_file_path  #cleaning up the directory
      @data_export.completed!
    rescue Exception => e
      @data_export.failure!(e.message + "\n" + e.backtrace.join("\n"))
      NewRelic::Agent.notice_error(e)
    end
    Account.reset_current_account
  end
  
  def delete_zip_file(zip_file_path)
    # Delete the Zip file and the Directory if exists
    if(File.exists?(@out_dir))
        FileUtils.remove_dir(@out_dir,true)
        FileUtils.rm_f(zip_file_path)
    end
    
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
  
  def export_companies_data
     companies = @current_account.companies.all  
     xml_output = companies.to_xml
     write_to_file("Companies.xml",xml_output)
  end
  
  def export_tickets_data
    i = 0 
    @current_account.tickets.find_in_batches(:batch_size => 300, :include => [:notes,:attachments]) do |tkts|
       xml_output = tkts.to_xml
       write_to_file("Tickets#{i}.xml",xml_output)
       i+=1
    end
  end

  def export_archived_tickets_data
    i = 0 
    @current_account.archive_tickets.find_in_batches(:batch_size => 300, :include => [:archive_notes,:attachments]) do |tkts|
       xml_output = tkts.to_xml
       write_to_file("ArchivedTickets#{i}.xml",xml_output)
       i += 1
    end
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
  
  def export_data   
      export_forums_data  #Forums data
      export_solutions_data #Solutions data
      export_users_data #Users data
      export_companies_data #Companies data
      export_tickets_data #Tickets data
      export_archived_tickets_data #Archived tickets data
      export_groups_data #Groups data
  end
  
end
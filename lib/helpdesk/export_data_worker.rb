require "tempfile"
require 'zip'
require 'zip/filesystem'
require 'fileutils'
require 'benchmark'

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

      options = {
          file_content: @file,
          filename: "#{Account.current.id}.zip",
          content_type: 'application/octet-stream',
          content_size: @file.size
      }
      att = Helpdesk::Attachment.create_for_3rd_party(Account.current, @file, options, 0, nil)
      att.update_attributes content_updated_at: Time.now.to_i,
                            attachable_id: @data_export.id,
                            attachable_type: "DataExport"
      att.save

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
      DataExportFailureMailer.data_backup_failure({:email => params[:email],
                                    :domain => params[:domain],
                                    :host => @current_account.host}
                                    )
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
    Zip::File.open(zip_file_path, Zip::File::CREATE) do |zipfile|
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
     solution_categories = @current_account.solution_category_meta.preload(:primary_category, 
          :solution_folder_meta => [:primary_folder, {:solution_article_meta => {:primary_article => :article_body}}])  
     xml_output = solution_categories.as_json(:root => false, :to_xml => true,
            :include => {:folders => {:include => :articles}}).to_xml(:root => "solution_categories")
     write_to_file("Solutions.xml",xml_output)
  end
  
  def export_users_data
     i = 0 
     @current_account.users.preload(:flexifield).find_in_batches(:batch_size => 300) do |users|
        xml_output = users.to_xml(:except => [:crypted_password,:password_salt,:persistence_token,:single_access_token,:perishable_token]) 
        write_to_file("Users#{i}.xml",xml_output)
        i+=1
     end
  end
  
  def export_companies_data
     i = 0 
     @current_account.companies.preload(:flexifield, :company_domains).find_in_batches(:batch_size => 300) do |companies|
        xml_output = companies.to_xml
        write_to_file("Companies#{i}.xml",xml_output)
        i+=1
     end
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
    @current_account.archive_tickets.find_in_batches(:batch_size => 300, :include => [:notes,:attachments]) do |tkts|
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
    Rails.logger.info "#{@current_account.id} : account export : started : starting forums"
    total = Benchmark.realtime {
      benchmark('Forums', 'Solutions') {export_forums_data} #Forums data
      benchmark('Solutions', 'Users') {export_solutions_data} #Solutions data
      benchmark('Users ', 'Companies') {export_users_data} #Users data
      benchmark('Companies', 'Tickets') {export_companies_data} #Companies data
      benchmark('Tickets', 'Archived Tickets') {export_tickets_data} #Tickets data
      benchmark('Archived Tickets', 'Groups') {export_archived_tickets_data} #Archived tickets data
      benchmark('Groups', 'upload : export completed') {export_groups_data} #Groups data
    }
    Rails.logger.info "#{@current_account.id} : account export total time : #{total}"
  end
  def benchmark(current_model, next_model)
    result = Benchmark.realtime{ yield }
    Rails.logger.info "#{@current_account.id} : account export : #{current_model} completed time_taken= #{result} : starting #{next_model}"
  end
end
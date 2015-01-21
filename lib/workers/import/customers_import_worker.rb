class Workers::Import::CustomersImportWorker < Struct.new(:params)
	include Helpdesk::ToggleEmailNotification
  include ImportCsvUtil
  include ActionController::UrlWriter

  #------------------------------------Customers include both contacts and companies-----------------------------------------------

  def perform
    begin
      initialize_params
      @csv_headers = @rows.shift
        @rows.each do |row|
          assign_field_values row
          save_item row       
        end
      unless @failed.blank?
        build_csv_file
        UserNotifier.deliver_notify_customers_import(mailer_params)
      else
        UserNotifier.deliver_notify_customers_import({:user => @current_user, 
                                                      :type => params[:type].pluralize.capitalize, 
                                                      :success =>true})
      end
      @item_import && @item_import.destroy
    rescue => e
      NewRelic::Agent.notice_error(e)
      puts "Error in #{params[:type]}_import ::#{e.message}\n#{e.backtrace.join("\n")}"
    ensure
      remove_import_file(file_path)
    end
	end

  def initialize_params
    params[:customers].symbolize_keys!
    set_current_account
    read_file params[:customers][:file_location]
    delete_file
  end

  def set_current_account
    @type = (type = params[:type]).eql?("company") ? type : "user"
    @current_account = Account.current || Account.find_by_id(params[:account_id])
    @current_user = (@current_account.user_emails.user_for_email(params[:email])).make_current
    @current_form = @current_account.send(:"#{params[:type]}_form")
    @item_import = @current_account.send(:"#{params[:type]}_import")
    disable_user_activation(@current_account)
  end

  def delete_file
    AwsWrapper::S3Object.delete(params[:customers][:file_location], S3_CONFIG[:bucket])
  end

  def assign_field_values row
    item_params = {}
    custom_field_params = {}
    default_fields = @current_form.default_fields.map(&:name)
    params[:customers][:fields].map { |field| default_fields.include?(field[0]) ? 
        item_params.merge!(:"#{field[0]}" => row[field[1].to_i]) : custom_field_params.merge!(:"#{field[0]}" => row[field[1].to_i]) }

    @params_hash = { :"#{@type}" => item_params.merge(:custom_field => custom_field_params) }
    default_validations
  end

  def default_validations
    case params[:type]
      when "contact"
        contact_validation
      when "company"
        company_validation
    end
    set_validatable_custom_fields unless @item.nil?
    refine_custom_checkbox 
  end

  def contact_validation
    item_param = @params_hash[:"#{@type}"]
    item_param[:name] = "" if item_param[:name].nil? && item_param[:email].blank?
    item_param[:client_manager] = item_param[:client_manager].to_s.strip.downcase == "yes" ? "true" : nil
    company_name = item_param[:company_name].to_s.strip
    item_param[:company_id]= @current_account.companies.find_or_create_by_name(company_name).id unless company_name.nil?
    search_options = {:email => item_param[:email], :twitter_id => item_param[:twitter_id]}
    @item = @current_account.all_users.find_by_an_unique_id(search_options)
  end

  def company_validation
    item_param = @params_hash[:"#{@type}"]
    return if item_param[:name].blank?
    company_name = item_param[:name].to_s.strip
    @item = @current_account.companies.find_by_name(company_name)
  end

  def set_validatable_custom_fields
    @item.validatable_custom_fields = { :fields => @current_form.custom_fields, 
                                          :error_label => :label }
  end

  def refine_custom_checkbox
    @cb_fields = []
    unless (custom_field = @params_hash[:user][:custom_field]).blank?
      @current_form.fields.map { |fd| @cb_fields << fd.name if fd.field_type == :custom_checkbox }
      custom_field.keys.map { |key|
        custom_field[:"#{key}"] = custom_field[:"#{key}"].to_s.strip.downcase == "yes" ? "true" : nil if @cb_fields.include?(key.to_s) }
    end
  end

  def save_item row
    created = updated = 0
    unless @item.nil?
      @params_hash[:user][:deleted] = false unless @type.eql?("company")#To make already deleted user active
      @item.update_attributes(@params_hash[:"#{@type}"]) ? updated+=1 : failed_item(row)
    else
      @item = @current_account.send("#{@type.pluralize}").new
      set_validatable_custom_fields
      create_item ? created+=1 : failed_item(row)
    end 
    enable_user_activation(@current_account)     
  end

  def create_item
    case params[:type]
      when "contact"
        @params_hash[:user][:helpdesk_agent] = false
        @item.signup!(@params_hash)
      when "company"
        @item.attributes = @params_hash[:company]
        @item.save
    end
  end

  def failed_item row
    @failed ||= []
    error_msg = @item.errors.map {|msg| (msg + @item.errors["#{msg}"])}.to_sentence
    @failed << row.push(error_msg)
  end

  def build_csv_file
    csv_string = CSVBridge.generate do |csv|
      csv << @csv_headers.push("errors")
      @failed.map {|item| csv << item}
    end
    write_file(csv_string)
  end

  def write_file file_string
    File.open(file_path , "wb") do |f|
      f.write(file_string)
    end
  end

  def file_path
    @file_path ||= begin
      output_dir = "#{Rails.root}/tmp" 
      FileUtils.mkdir_p output_dir
      file_path = "#{output_dir}/#{file_name}"
      file_path
    end
  end

  def file_name
    "failed_#{params[:customers][:file_name]}"
  end

  def file_size
    File.size(file_path)
  end

  def mailer_params
    unless file_size > ONE_MEGABYTE
      {
        :user => @current_user, 
        :type => params[:type].pluralize.capitalize, 
        :unsaved_item => "please find the attachment", 
        :file_path => file_path, :file_name => file_name
      }
    else
      {
        :user => @current_user, 
        :type => params[:type].pluralize.capitalize, 
        :unsaved_item => "you have more unsaved #{params[:type].pluralize}"
      }
    end
  end

  def remove_import_file(file_path)
    FileUtils.rm_f(file_path)
  end
end
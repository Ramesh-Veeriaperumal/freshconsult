class Import::Customers::Base
  include Helpdesk::ToggleEmailNotification
  include ImportCsvUtil

  #------------------------------------Customers include both contacts and companies-----------------------------------------------

  def initialize(params)
    @failed_items = []
    @params = params
    @created = @updated = 0
    @customer_params = params[:customers].symbolize_keys!
    @type = params[:type].eql?("company") ? "company" : "user"
    set_current_user
  end

  def import
    Thread.current["customer_import_#{current_account.id}"] = true
    read_file @customer_params[:file_location]
    mapped_fields
    build_csv_file unless @failed_items.blank?
    notify_and_cleanup
  rescue CSVBridge::MalformedCSVError => e
    NewRelic::Agent.notice_error(e, {:description => "Error in CSV file format :: #{@params[:type]}_import :: #{current_account.id}"})
    @wrong_csv = e.to_s
    notify_and_cleanup
  rescue => e
    NewRelic::Agent.notice_error(e, {:description => "Error in #{@params[:type]}_import :: account_id :: #{current_account.id}"})
    puts "Error in #{@params[:type]}_import ::#{e.message}\n#{e.backtrace.join("\n")}"
    customer_import.failure!(e.message + "\n" + e.backtrace.join("\n"))
    notify_mailer(true)
  ensure
    Thread.current["customer_import_#{current_account.id}"] = false
    enable_user_activation(current_account)
    cleanup_file
  end

  private

  def mapped_fields
    @csv_headers = @rows.shift
    @rows.each do |row|
      assign_field_values row
      next if is_user? && !@item.nil? && @item.helpdesk_agent?     
      save_item row
    end    
  end

  def assign_field_values row
    item_params = {}
    custom_field_params = {}
    default_fields = @current_form.default_fields.map(&:name)
    @customer_params[:fields].map { |field| default_fields.include?(field[0]) ? 
        item_params.merge!(:"#{field[0]}" => row[field[1].to_i]) : custom_field_params.merge!(:"#{field[0]}" => row[field[1].to_i]) }

    @params_hash = { :"#{@type}" => item_params.merge(:custom_field => custom_field_params) }
    default_validations
    refine_custom_checkbox
  end

  def save_item row
    @item = current_account.send("#{@type.pluralize}").new if @item.blank?
    set_validatable_custom_fields
    construct_company_params if is_user? && Account.current.features?(:multiple_user_companies)
    unless @item.new_record?
      @item.update_attributes(@params_hash[:"#{@type}"]) ? @updated+=1 : failed_item(row)
    else
      send("create_imported_#{@params[:type]}") ? @created+=1 : failed_item(row)
    end
  end

  def construct_company_params
    construct_import_companies_params
    @item.update_companies(@params_hash) unless @item.new_record?
    @params_hash[:user].delete(:client_manager)
    @params_hash[:user].delete(:company_name)
  end

  def set_current_user
    @current_user = (current_account.user_emails.user_for_email(@params[:email])).make_current
    @current_form = current_account.send("#{@params[:type]}_form")
    @cf_type = @current_form.custom_fields
    disable_user_activation(current_account)
  end

  def current_account
    @account ||= (Account.current || Account.find_by_id(params[:account_id]))
  end

  def customer_import
    @import ||= current_account.send("#{@params[:type]}_import")
  end

  def is_user?
    @type == "user"
  end

  def set_validatable_custom_fields
    @item.validatable_custom_fields = { :fields => @cf_type, :error_label => :label }
  end

  def refine_custom_checkbox
    @cb_fields = []
    unless (custom_field = @params_hash[:"#{@type}"][:custom_field]).blank?
      @cf_type.map { |fd| @cb_fields << fd.name if fd.custom_checkbox? }
      custom_field.keys.map do |key|
        if @cb_fields.include?(key.to_s)
          field_value = custom_field[:"#{key}"].to_s.strip.downcase
          custom_field[:"#{key}"] = ["yes","true"].include?(field_value) ? "true" : "false" unless field_value.blank?
        end
      end
    end
  end

  def failed_item row
    error_msg = @item.errors.map {|msg| (msg.to_s) +" "+ (@item.errors["#{msg}"].to_s)}.to_sentence
    @failed_items << row.push(error_msg)
  end

  # Building csv file for failed items.

  def build_csv_file
    customer_import.file_creation!
    csv_string = CSVBridge.generate do |csv|
      csv << @csv_headers.push("errors")
      @failed_items.map {|item| csv << item}
    end
    write_file(csv_string)
    customer_import.completed!
  end

  def write_file file_string
    File.open(failed_file_path , "wb") do |f|
      f.write(file_string)
    end
  end

  def failed_file_path
    @failed_file_path ||= begin
      output_dir = "#{Rails.root}/tmp" 
      FileUtils.mkdir_p output_dir
      file_path = "#{output_dir}/#{failed_file_name}"
      file_path
    end
  end

  def failed_file_name
    "failed_#{@customer_params[:file_name]}"
  end

  def failed_file_size
    File.size(failed_file_path)
  end

  def notify_and_cleanup
    customer_import && customer_import.destroy
    notify_mailer
  end

  def notify_mailer param = false
    UserNotifier.notify_customers_import(mailer_params(param))
  end

  def mailer_params corrupted
    hash = { 
      :user => @current_user,
      :type => @params[:type].pluralize,
      :created_count => @created,
      :updated_count => @updated,
      :failed_count => @failed_items.count
    }

    if corrupted
      hash.merge!(:corrupted => true)
    elsif @wrong_csv
      hash.merge!(:wrong_csv => @wrong_csv)
    else
      # Attachment(csv file) will not be send, if the file is more than 1MB
      hash.merge!(:file_path => failed_file_path, :file_name => failed_file_name) unless @failed_items.blank? || failed_file_size > ONE_MEGABYTE 
      hash.merge!(:import_success => true) if @failed_items.blank?
    end
    hash
  end

  def cleanup_file
    FileUtils.rm_f(failed_file_path) unless @failed_items.blank?
    AwsWrapper::S3Object.delete(@customer_params[:file_location], S3_CONFIG[:bucket])
  rescue => e
    NewRelic::Agent.notice_error(e, {:description => "Error while removing file from s3 :: account_id :: #{current_account.id}"})
  end

  def construct_import_companies_params
    company_names = @params_hash[:user][:company_name].split(COMPANY_DELIMITER)
    client_manager_values = @params_hash[:user][:client_manager].split(COMPANY_DELIMITER)

    client_manager_values.map!(&->(c){VALID_CLIENT_MANAGER_VALUES.include?(c) ? 1 : 0})

    import_companies = {}
    company_names.each_with_index do |company, index|
      unless import_companies.keys.include?(company) || company.blank?
        import_companies[company] = client_manager_values[index]
      end
    end

    user_companies = @item.companies.preload(:user_companies).
                      select(['user_companies.client_manager', 'user_companies.default',
                              'customers.id', 'customers.name']).
                      inject({}) do |res, u|
                        res[u.name] = {
                                        :id => u.id, 
                                        :client_manager => u.client_manager,
                                        :default => u.default
                                      }
                        res
                      end
    edited = import_companies.keys & user_companies.keys
    added = import_companies.keys - edited
    removed_companies = user_companies.keys - edited

    added_companies = added.inject([]) do |res, comp|
      res << create_company_details(comp, import_companies[comp],
                                comp == @params_hash[:user][:first_company_name])
    end

    edited_companies = edited.inject([]) do |res, comp|
      default_value = (comp == @params_hash[:user][:first_company_name]) ? 1 : 0
      res << create_company_details(comp, import_companies[comp], default_value, user_companies[comp][:id]) unless
                        import_companies[comp] == user_companies[comp][:client_manager] &&
                        default_value == user_companies[comp][:default] && removed_companies.empty?
      res
    end

    @params_hash[:user][:added_companies] = added_companies.to_json
    @params_hash[:user][:removed_companies] = removed_companies.to_json
    @params_hash[:user][:edited_companies] = edited_companies.to_json
  end

  def create_company_details(company_name, client_manager, default_value, company_id=nil)
    {
      "id" => company_id,
      "company_name" => company_name,
      "client_manager" => client_manager,
      "default_company" => default_value
    }
  end
end
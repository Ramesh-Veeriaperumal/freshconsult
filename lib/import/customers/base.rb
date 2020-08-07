class Import::Customers::Base
  include Helpdesk::ToggleEmailNotification
  include ImportCsvUtil
  include CustomerImportConstants
  include Redis::RedisKeys
  include Redis::OthersRedis

  #------------------------------------Customers include both contacts and companies-----------------------------------------------

  def initialize(params)
    @failed_items = []
    @failed_count = 0
    @params = params
    @created = @updated = 0
    @customer_params = params[:customers].symbolize_keys!
    @type = params[:type].eql?("company") ? "company" : "user"
    set_current_user
  end

  def import
    Thread.current["customer_import_#{current_account.id}"] = true
    customer_import.update_attribute(:created_at, Time.now.utc)
    parse_csv_file
    build_error_csv_file unless @failed_items.blank?
    handle_import_cancel
    Rails.logger.debug "Customer stopped the #{@params[:type]} import" if redis_key_exists?(stop_redis_key) && !@is_outreach_import
    Rails.logger.debug "#{@params[:type]} import completed. 
                        Total records:#{total_rows_to_be_imported}
                        Created:#{@created} 
                        Updated:#{@updated}
                        Time taken:#{Time.now.utc - customer_import.created_at.utc}".squish
  rescue CSVBridge::MalformedCSVError => e
    NewRelic::Agent.notice_error(e, {:description => "Error in CSV file format :: 
      #{@params[:type]}_import :: #{current_account.id}"})
    @wrong_csv = e.to_s
    customer_import.failure!(e.message + "\n" + e.backtrace.join("\n"))
  rescue => e
    NewRelic::Agent.notice_error(e, {:description => "Error in #{@params[:type]}_import :: 
      account_id :: #{current_account.id}"})
    puts "Error in #{@params[:type]}_import ::#{e.message}\n#{e.backtrace.join("\n")}"
    Rails.logger.debug "Error during #{@params[:type]} import : 
          #{Account.current.id} #{e.message} #{e.backtrace}".squish
    customer_import.failure!(e.message + "\n" + e.backtrace.join("\n"))
    corrupted = true
  ensure
    notify_and_cleanup(corrupted)
    Thread.current["customer_import_#{current_account.id}"] = false
    enable_user_activation(current_account)
    cleanup_file
  end

  private

    def handle_import_cancel
      if !@is_outreach_import && redis_key_exists?(stop_redis_key)
        customer_import && customer_import.cancelled!
      else
        customer_import && customer_import.completed!
      end
    end

  def parse_csv_file
    csv_file = AwsWrapper::S3.read_io(S3_CONFIG[:bucket], @customer_params[:file_location])
    total_rows = total_rows_to_be_imported
    completed_rows = 0

    CSVBridge.parse(content_of(csv_file)).each_slice(IMPORT_BATCH_SIZE).with_index do |rows, index|
      raise CSVBridge::MalformedCSVError unless valid_csv_records? rows

      @failed_count = 0
      rows.each_with_index do |row, inner_index|
        row = row.collect { |r| Helpdesk::HTMLSanitizer.clean(r.to_s).gsub(/&amp;/, AND_SYMBOL) }
        (@csv_headers = row) && next if index==0 && inner_index==0
        assign_field_values row
        next if is_user? && !@item.nil? && @item.helpdesk_agent?
        save_item row
      end
      completed_rows += IMPORT_BATCH_SIZE
      processed_count = completed_rows > total_rows ? total_rows - (completed_rows - IMPORT_BATCH_SIZE) : IMPORT_BATCH_SIZE
      update_completed_rows processed_count
      update_failed_rows @failed_count unless @failed_count.zero?
      break if redis_key_exists?(stop_redis_key)
    end
  rescue => e
    Rails.logger.error "Error while reading csv data ::#{e.message}\n#{e.backtrace.join("\n")}"
    NewRelic::Agent.notice_error(e, {:description => 
      "The file format is not supported. Please check the CSV file format!"})
    raise e
  end

  def valid_csv_records?(rows)
    records = Nokogiri::HTML(rows.join(','))
    records.traverse do |node|
      return false if INVALID_FILE_TAGS.include?(node.name)
    end
    true
  end
  
  def stop_redis_key
    @stop_redis_key ||= format(Object.const_get("STOP_#{@params[:type].upcase}_IMPORT"),
                         account_id: Account.current.id)
  end

  def update_completed_rows processed_count
    key = format(Object.const_get("#{@params[:type].upcase}_IMPORT_FINISHED_RECORDS"),
            account_id: Account.current.id, import_id: @import.id)
    increment_others_redis(key, processed_count)
  end
  
  def total_rows_to_be_imported
    key =  format(Object.const_get("#{@params[:type].upcase}_IMPORT_TOTAL_RECORDS"),
            account_id: Account.current.id, import_id: @import.id)
    get_others_redis_key(key).to_i
  end

  def update_failed_rows failed_count
    key = format(Object.const_get("#{@params[:type].upcase}_IMPORT_FAILED_RECORDS"),
           account_id: Account.current.id, import_id: @import.id)
    increment_others_redis(key, failed_count)
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
    @item = current_account.safe_send("#{@type.pluralize}").new if @item.blank?
    set_validatable_custom_fields
    construct_company_params if import_multiple_companies?
    set_company_validatable_fields if @type == "company" && Account.current.tam_default_fields_enabled?
    construct_user_emails_param if is_user? && @params_hash[:"#{@type}"].keys.include?(:all_emails)
    unless @item.new_record?
      begin
        @item.update_attributes(@params_hash[:"#{@type}"]) ? @updated+=1 : failed_item(row)
        save_contact_id if @is_outreach_import
      rescue Exception => e
        Rails.logger.debug "Error importing contact during update : 
          #{Account.current.id} #{@params_hash.inspect} #{e.message} #{e.backtrace}".squish
        failed_item(row)
      end
    else
      safe_send("create_imported_#{@params[:type]}") ? @created+=1 : failed_item(row)
      save_contact_id if @is_outreach_import
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
    @current_form = current_account.safe_send("#{@params[:type]}_form")
    @cf_type = @current_form.custom_fields
    disable_user_activation(current_account)
  end

  def current_account
    @account ||= (Account.current || Account.find_by_id(params[:account_id]))
  end

  def customer_import
    @import ||= current_account.safe_send("#{@params[:type]}_imports").find(@params[:data_import])
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
    @failed_count += 1
  end

  # Building csv file for failed items.

  def build_error_csv_file
    customer_import && customer_import.file_creation!
    csv_string = CSVBridge.generate do |csv|
      csv << @csv_headers.push("errors")
      @failed_items.map {|item| csv << item}
    end
    csv_string = reduce_csv_string(csv_string) if csv_string.bytesize > FIVE_MEGABYTE
    write_file(csv_string)
    build_failed_attachment
  end

    def reduce_csv_string(csv_string)
      reduced_failed_items = @failed_items.slice(0, (@failed_items.length.to_f / (csv_string.bytesize.to_f / FIVE_MEGABYTE).ceil).floor)
      reduced_csv_string = CSVBridge.generate do |csv|
        csv << @csv_headers.push('errors')
        reduced_failed_items.map { |item| csv << item }
      end
      reduced_csv_string
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

  def build_failed_attachment
    file = File.open(failed_file_path, 'r')
    failed_attachment = customer_import.attachments.build(content: file, account_id: current_account.id)
    failed_attachment.save!
  end

  def notify_and_cleanup(corrupted = false)
    notify_mailer corrupted
    remove_stop_import_key
  end


  def remove_stop_import_key
    remove_others_redis_key stop_redis_key
  end

  def notify_mailer param = false
    UserNotifier.send_email(:notify_customers_import, @current_user.email, mailer_params(param))
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
      # Sample attachment(csv file) will be send, if the file is more than 5MB
      hash.merge!(file_path: failed_file_path, file_name: failed_file_name) unless @failed_items.blank? || failed_file_size > FIVE_MEGABYTE
      hash.merge!(:attachments => customer_import.attachments.all) unless @failed_items.blank?
      hash.merge!(:import_success => true) if @failed_items.blank? && !redis_key_exists?(stop_redis_key)
      hash.merge!(:import_stopped => true) if redis_key_exists?(stop_redis_key)
    end
    hash
  end

  def cleanup_file
    AwsWrapper::S3.delete(S3_CONFIG[:bucket], @customer_params[:file_location])
  rescue => e
    NewRelic::Agent.notice_error(e, {:description => "Error while removing file from s3 :: account_id :: #{current_account.id}"})
  end

  def construct_user_emails_param
    import_emails = @params_hash[:user][:all_emails]

    user_emails = @item.user_emails.
                  select(['user_emails.id', 'user_emails.primary_role',
                          "user_emails.email"]).
                  inject({}) do |res, em|
                    res[em.email.downcase] = {
                                "id" => em.id,
                                "primary_role" => em.primary_role
                    }
                    res
                  end

    existing_emails = import_emails & user_emails.keys
    added_emails = import_emails - existing_emails
    removed_emails = user_emails.keys - existing_emails


    user_email_attributes = import_emails.each_with_index.
                              inject({}) do |email_attrs, (email, index)|
      is_primary = (index == 0) ? "1" : "0"
      if added_emails.include?(email)
        email_attrs[index.to_s] = create_user_emails_details(email,
                                    is_primary, "false")
      elsif existing_emails.include?(email)
        email_attrs[index.to_s] = create_user_emails_details(email,
                                    is_primary, "false", user_emails[email]["id"])
      end
      email_attrs
    end

    removed_emails.each_with_index do |email, index|
      indx = (import_emails.length + index).to_s
      user_email_attributes[indx] = create_user_emails_details(email,
                                            false, "true",
                                            user_emails[email]["id"])
    end

    @params_hash[:user].delete(:email)
    @params_hash[:user].delete(:all_emails)
    @params_hash[:user][:user_emails_attributes] = user_email_attributes
  end

  def construct_import_companies_params
    company_names = @params_hash[:user][:company_name].split(IMPORT_DELIMITER)
    client_manager_values = @params_hash[:user][:client_manager].split(IMPORT_DELIMITER)

    client_manager_values.map!(&->(c){VALID_CLIENT_MANAGER_VALUES.include?(c) ? 1 : 0})

    import_companies = {}
    company_names.each_with_index do |company, index|
      unless import_companies.keys.include?(company) || company.blank?
        import_companies[company] = client_manager_values[index]
      end
    end

    import_companies_case_mapping = import_companies.keys.map{|c| [c.downcase, c]}.to_h

    user_companies = @item.companies.preload(:user_companies).
                      select(['user_companies.client_manager', 'user_companies.default',
                              'customers.id', 'customers.name']).
                      inject({}) do |res, u|
                        res[u.name.downcase] = {
                                        :id => u.id, 
                                        :client_manager => u.client_manager,
                                        :default => u.default
                                      }
                        res
                      end
    edited_case_map = (import_companies_case_mapping.keys & user_companies.keys)
    edited = edited_case_map.map{|c| import_companies_case_mapping[c]}

    added = (import_companies_case_mapping.keys - edited_case_map).map{|c| import_companies_case_mapping[c]}
    removed_companies = (user_companies.keys - edited_case_map)

    added_companies = added.inject([]) do |res, comp|
      res << create_company_details(comp, import_companies[comp],
                                    comp == @params_hash[:user][:first_company_name])
    end

    edited_companies = edited.inject([]) do |res, comp|
      default_value = (comp == @params_hash[:user][:first_company_name]) ? 1 : 0
      res << create_company_details(comp, import_companies[comp], default_value,
                                    user_companies[comp.downcase][:id]) 
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

  def import_multiple_companies?
    is_user? && Account.current.multiple_user_companies_enabled? &&
    @params_hash[:"#{@type}"].keys.include?(:company_name)
  end

  def set_company_validatable_fields
    @item.validatable_default_fields = { :fields => current_account.company_form.default_company_fields,
                                         :error_label => :label }
  end

  def create_user_emails_details(email, primary_role, destroy, user_email_id=nil)
    {
      "email" => email,
      "primary_role" => primary_role,
      "id" => user_email_id,
      "_destroy" => destroy
    }
  end
end

namespace :csv_report do 


  PARAMETERS = ["DATE_RANGE", "ACCOUNT_IDS", "EMAIL_IDS", "BENCHMARK", "WEEKDAY", "RESET_REDIS_KEY", "DESCRIPTION"]

  MANDATORY_PARAMETERS = ["DATE_RANGE", "ACCOUNT_IDS", "EMAIL_IDS"]

  OPTIONAL_PARAMETERS = PARAMETERS - MANDATORY_PARAMETERS

  QUERY_METRIC = ["GLANCE_CURRENT", "GLANCE_HISTORIC"]

  BATCH_SIZE = 500

  TASK_IN_PROGRESS = 'task_in_progress'
  
  CSV_TERMS = { 'account_id'              => 'Account ID', 
                'received_tickets'        => 'Created Tickets',
                'resolved_tickets'        => 'Resolved Tickets',
                'reopened_tickets'        => 'Reopened Tickets',
                'avg_first_response_time' => 'Avg 1st Response Time',
                'avg_response_time'       => 'Avg Response Time',
                'avg_resolution_time'     => 'Avg Resolution Time',
                'avg_first_assign_time'   => 'Avg 1st Assign Time',
                'fcr_tickets'             => 'FCR %',
                'response_sla'            => 'First Response SLA %',
                'resolution_sla'          => 'Resolution SLA %' }

  # PARAMETERS :
  # DATE_RANGE  = start date & end date as string (or) diff between dates  // "1 Jan, 2016 - 1 Feb,2016" (or) 90
  # ACCOUNT_IDS = comma separated string of account ids or 'all_active' // "acc_id1, acc_id2"
  # EMAIL_IDS   = comma separated string of email ids // "mail_id1, mail_id2"
  # WEEKDAY     = To generate report during weekdays (true / false) OPTIONAL
  # BENCHMARK   = To set reference as true/false
  # RESET_REDIS_KEY = true / false. False by default. Resets Redis key
  # DESCRIPTION = Short description of report requested.

  desc "Exports report requested by internal teams"
  
  task :send_email => :environment do 

    include HelpdeskReports::Helper::Ticket
    include Redis::ReportsRedis
    include Redis::RedisKeys

    @task_start_time = Time.now.utc
    @task_id = "#{@task_start_time.to_s.gsub(/\s+/,'_')}"
    Rails.logger.info "CSV EXPORT task id : #{@task_id}  ; BEGINS AT : #{@task_start_time}"

    MANDATORY_PARAMETERS.each { |param| display_param_structure unless ENV[param].present? }
    
    puts "\nTASK ID : #{@task_id}\n"
    
    date_range      = ENV["DATE_RANGE"]
    account_ids_str = ENV["ACCOUNT_IDS"]
    email_ids       = ENV["EMAIL_IDS"]
    override        = ENV["WEEKDAY"] ? ENV["WEEKDAY"].to_bool : false
    @benchmark      = ENV["BENCHMARK"] || false
    reset_redis_key = ENV["RESET_REDIS_KEY"] || false
    @description    = ENV["DESCRIPTION"]

    remove_reports_redis_key Redis::RedisKeys::BI_REPORTS_INTERNAL_CSV_EXPORT if reset_redis_key

    lock = get_reports_redis_key Redis::RedisKeys::BI_REPORTS_INTERNAL_CSV_EXPORT
    execute_today = (override || ["sat","sun"].include?(Time.now.strftime("%a").downcase))
    if (lock.nil? && execute_today)
      begin 
        execute_task(date_range, account_ids_str, email_ids)
      rescue => err 
        subject = "Error in internal custom CSV export to customer support team"
        message = "#{err.message}\n\n#{err.backtrace}"
        DevNotification.publish(SNS["reports_notification_topic"], subject, message)
      ensure
        remove_reports_redis_key Redis::RedisKeys::BI_REPORTS_INTERNAL_CSV_EXPORT
      end
    else 
      puts "\n #{'*' * 100}"
      puts "\n\nCannot execute tasks simultaneously. Wait for the previous process to complete" if lock
      puts "\n\nIt is advisable to generate CSV Report only on weekends to avoid any performance issue in server.\n\n ***** Use variable WEEKDAY='true' to run immediately *****\n\n" unless execute_today
      puts "\n #{'*' * 100}\n"
    end

  end

  def execute_task date_range, account_ids_str, email_ids
    set_reports_redis_key(Redis::RedisKeys::BI_REPORTS_INTERNAL_CSV_EXPORT, TASK_IN_PROGRESS)
    prepare_data(date_range, account_ids_str, email_ids)
    requests = build_requests
    Rails.logger.info "CSV EXPORT task id : #{@task_id} ; DATA RETRIEVAL BEGINS : #{Time.now.utc}\n CSV export task id : #{@task_id} ; NO. OF ACCOUNTS TO BE PROCESSED : #{@accounts.count}"
    response = execute_requests requests
    Rails.logger.info "CSV EXPORT task id : #{@task_id}  ; DATA RETRIEVAL ENDS : #{Time.now.utc}"
    result = format_result response
    csv_string = build_csv_string result
    file_path = build_file(csv_string) 
    send_email(file_path)
    FileUtils.rm_f(file_path) if file_path
  end

  def prepare_data date_range,account_ids_str,email_ids
    @date_range = ( date_range.include?("-") || date_range.match(/^[0-9]+\s*[a-zA-Z]+,\s*[0-9]+/) ) ? date_range : set_date_range(date_range.to_i)
    @accounts = get_accounts_details account_ids_str
    @email_ids = email_ids.split(",")
  end

  def get_accounts_details account_ids_str
    @invalid_accounts, account_details = [], []
    if account_ids_str.strip.downcase=='all_active'
      Sharding.run_on_all_slaves do 
        Account.active_accounts.select('accounts.id, accounts.time_zone').find_in_batches(batch_size: BATCH_SIZE) do |account_arr|
          account_details << account_arr
        end
      end
      account_details = account_details.flatten.uniq
      @all_active_accounts = true
    else
      account_ids_arr = account_ids_str.split(",").uniq
      Sharding.run_on_all_slaves do 
        Account.where(id: account_ids_arr).select('id,time_zone').find_in_batches(batch_size: BATCH_SIZE) do |account_arr|
          account_details << account_arr
        end
      end
      account_details = account_details.flatten.uniq
      @invalid_accounts  = account_ids_arr - account_details.collect{|acc| "#{acc[:id]}"} if account_ids_arr.size != account_details.size
      @all_active_accounts = false
    end
    account_details
  end

  def set_date_range date_range
    @date_range_days = date_range
    date_format = "%e %b, %Y"
    end_date = Time.current
    start_date = end_date - date_range.days
    "#{start_date.strftime(date_format)} - #{end_date.strftime(date_format)}"
  end

  def basic_params
    {
      model:  :TICKET,
      reference: true,
      filter: nil,
      group_by: nil,
      bucket: false,
      list: false,
      time_trend: false,
      bucket_conditions: nil,
      list_conditions: nil,
      time_trend_conditions: nil,
      report_type: :glance,
      minimum_reference: (@benchmark ? false : true),
      cache_result: (@benchmark ? true : false)
    }
  end

  def build_requests
    requests = []
    req_params = basic_params.merge(date_range: @date_range)
    @accounts.each do |account|
      QUERY_METRIC.each do |metric|
        requests << {req_params: req_params.merge(metric: metric,account_id: account.id, time_zone: account.time_zone, index: account.id)}
      end
    end
    requests
  end

  def execute_requests requests
    response = []
    limit = 10
    start_limit = 0
    while(start_limit < requests.length)
      batch_req = requests.slice(start_limit,limit)
      response << bulk_request(batch_req)
      start_limit = start_limit+limit
      Rails.logger.info "CSV EXPORT task id : #{@task_id} ; Processed #{start_limit} accounts" if (start_limit%1000==0)
    end
    response.flatten!
  end

  def format_result response
    result = []
    current_time_range = Hash.new { |hash, key| hash[key] = {} }
    response.each do |res|
      res['result'].each do |r|
        current_time_range[res['index']].merge!(r.merge('account_id' => res['index']).except('range_benchmark')) if r['range_benchmark'] == 't'
      end
    end
    result << current_time_range.values
    result.flatten
  end

  def build_csv_string result
    csv_headers = CSV_TERMS.values
    csv_keys = CSV_TERMS.keys
    csv_string = CSVBridge.generate do |csv|
      csv << csv_headers
      result.each do |record_hash|
        row = []
        csv_keys.each { |key| row << presentable_format(record_hash[key],key)  }
        csv << row
      end
      csv << ["Invalid Accounts"] if @invalid_accounts.present?
      @invalid_accounts.each {|account_no| csv << [account_no] }
    end
    csv_string
  end

  def build_file csv_string
    file_name = "Data_analysis_for_multiple_accounts-#{Time.current.strftime("%d-%b-%y-%H:%M")}-#{SecureRandom.urlsafe_base64(4)}.csv"
    file_path = generate_file_path file_name
    write_file(csv_string, file_path)
    file_path
  end

  def generate_file_path file_name
    output_dir = "#{Rails.root}/tmp/export/common_data_analysis/csv/#{Time.current.strftime("%d-%b-%y")}"
    FileUtils.mkdir_p output_dir
    file_path = "#{output_dir}/#{file_name}"
    file_path
  end

  def write_file file_string, file_path
    File.open(file_path , "wb") do |f|
      f.write(file_string)
    end
  end

  def send_email file_path
    msg = @all_active_accounts ? "all active" : "requested"
    date_range_msg = @date_range_days ?  "#{@date_range} (Last #{@date_range_days} days)" : "#{@date_range}"
    email_subject = @description ? "#{@description} #{date_range_msg}" : "CSV report for #{msg} Freshdesk accounts (#{date_range_msg})"
    options = { invalid_count: @invalid_accounts.size,
                file_path: file_path,
                task_email_ids: @email_ids,
                date_range: date_range_msg,
                email_subject: email_subject,
                task_start_time: @task_start_time.in_time_zone('Chennai'),
                description: @description }
    ReportExportMailer.report_export_task(options)
    Rails.logger.info "CSV EXPORT task id : #{@task_id}  ; ENDS AT : #{Time.now.utc}"
  end

  def display_param_structure
    puts "\n #{'*' * 100}\n"
    puts "****Provide all mandatory parameters****\n\nMANDATORY_PARAMETERS : \n DATE_RANGE='1 Jan, 2016 - 1 Feb, 2016' or last n days(Ex.: 30, 60 or any number)\n ACCOUNT_IDS='1,2,3,4' (comma separated values)\n EMAIL_IDS='a@gmail.com,b@gmail.com' \n\nOPTIONAL PARAMETERS :\n WEEKDAY='true' (To generate report in weekdays)\n DESCRIPTION = Short description of report requested.\n\n\t *******\n"
    puts "\n #{'*' * 100}\n"
    exit
  end

  def presentable_format value, metric
    metric.starts_with?("avg") ? hhmm(value) : value
  end
  
  def hhmm(seconds)
    seconds = seconds.to_i
    hh = (seconds/3600).to_i
    mm = ((seconds % 3600) / 60).to_i
    ss = (seconds % 60).to_i
    "#{hh.to_s.rjust(2,'0')}:#{mm.to_s.rjust(2,'0')}:#{ss.to_s.rjust(2,'0')}"
  end

end
namespace :account_metrics do
  
  desc "Moving all resources"
  task :move_metrics_data_to_s3 => :environment do
    require "#{Rails.root}/lib/account_metric_helper_methods"
    include AccountMetricHelperMethods

    @date = Time.now.utc.strftime("%d-%m-%Y")
    begin
      @start_time = Time.now.utc
      build_account_csv
      build_resource_csv 
      build_model_resource_csv
      trigger_devops_admin_import
      @end_time = Time.now.utc
      send_confirmation_mailer
    rescue Exception => e
      deliver_error_mailer(e)
    end
    
  end

  def build_account_csv    
    csv_string = CSVBridge.generate do |csv|
      csv << FIELDS[:accounts]
      Sharding.run_on_all_slaves do
        Account.active_accounts.find_in_batches(:batch_size => 500, 
          :include => [:subscription]) do |accounts|
          accounts.each do |account|
            begin
              account.make_current
              subscription = account.subscription
              csv << [
                account.id, account.full_domain, account.created_at.to_s(:db), subscription.state, 
                subscription.subscription_plan.name, subscription.agent_limit, subscription.renewal_period,
                subscription.cmrr
              ]
              Account.reset_current_account
            rescue => e
              Rails.logger.debug("Error while building accounts data - #{account.id}")
            end
          end
        end
      end
    end

    write_to_file(csv_string, %(accounts.csv))
    push_file_to_s3(%(accounts.csv))
    delete_file(%(accounts.csv))
  end

  def build_resource_csv
    Sharding.run_on_all_slaves do
      Account.active_accounts.find_in_batches(:batch_size => 500) do |accounts|
        accounts.each do |account|
          begin
            account.make_current
            csv_string = CSVBridge.generate do |csv|
              csv << FIELDS[:resources]
              account.features.map{ |f| csv << [f.account_id, f.to_sym.to_s] }
              account.installed_applications.map{ |app| csv << [app.account_id, app.application.name] }
              activity_data(account, csv)
            end

            write_to_file(csv_string, %(resources_#{account.id}.csv))
            push_file_to_s3(%(resources_#{account.id}.csv))
            delete_file(%(resources_#{account.id}.csv))
            Account.reset_current_account
          rescue => e
            Rails.logger.debug("Error while building resources data - #{account.id}")
          end
        end
      end
    end
  end

  def build_model_resource_csv    
    Sharding.run_on_all_slaves do
      Account.active_accounts.find_in_batches(:batch_size => 500) do |accounts|
        accounts.each do |account|
          begin
            csv_string = CSVBridge.generate do |csv|
              csv << FIELDS[:model_resources]
              build_model_data(account).each do |model_data|      
                csv << [account.id, model_data[0], model_data[1]]
              end
            end

            write_to_file(csv_string, %(model_resources_#{account.id}.csv))
            push_file_to_s3(%(model_resources_#{account.id}.csv))
            delete_file(%(model_resources_#{account.id}.csv))
          rescue => e
            Rails.logger.debug("Error while building model resources data - #{account.id}")
          end
        end
      end
    end
  end

  def activity_data(account, data)
    ACTIVITIES.each do |k, v|
      agent_ids = account.agents.collect{ |a| a.user_id }
      activity = account.activities.order("id DESC").limit(1) 
                                   .where(["notable_type IN (?) and user_id in (?) AND created_at > ?", v, agent_ids, 10.days.ago]).first
      data << [account.id, k] if activity
    end
    data
  end

  def write_to_file(csv_string, file_name)
    file_path = File.join("#{Rails.root}", "tmp", file_name)
    File.open(file_path, 'w') {|f| f.write(csv_string) }
  end

  def push_file_to_s3(file_name)
    file_path = File.join("#{Rails.root}", "tmp", file_name)
    aws_path = %(#{@date}/#{File.basename(file_path)})
    AwsWrapper::S3.put(S3_BUCKET, aws_path, File.open(file_path), server_side_encryption: 'AES256')
  end 

  def delete_file(file_name)
    file_path = File.join("#{Rails.root}", "tmp", file_name)
    File.delete(file_path)
  end

  def trigger_devops_admin_import
    hrp = HttpRequestProxy.new
    requestParams = { :method => "get", :user_agent => USER_AGENT, :auth_header => auth_header }

    response = hrp.fetch_using_req_params(build_request_params, requestParams)
  end

  def build_request_params
    {
      :domain => AdminApiConfig[Rails.env]["url"], 
      :rest_url => AdminApiConfig[Rails.env]["resource_import_api"],
      :method => :get, 
      :ssl_enabled => "true", 
      :content_type => "application/json",
      :body => {:date => @date}.to_json
    }
  end

  def auth_header
    username = AdminApiConfig[Rails.env]["authorization_username"]
    password = AdminApiConfig[Rails.env]["authorization_password"]
    'Basic ' + Base64.encode64("#{username}:#{password}")
  end

  def send_confirmation_mailer
    FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
      {
        :subject => "move_metrics_data_to_s3 completed!",
        :recipients => "vijayaraj@freshdesk.com",
        :additional_info => { :start_time => @start_time, :end_time => @end_time }
      }
    )
  end

  def deliver_error_mailer(e)
    FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
      {
        :subject => "Error when pulling data for metrics",
        :recipients => "vijayaraj@freshdesk.com",
        :additional_info  => { :error => e }
      }
    )
  end

end

FIELDS = {
  :accounts => ["account_id", "domain", "signed_up_at", "state", "plan", "agents_subscribed", 
    "renewal_period", "cmrr"],
  :resources => ["account_id", "name"],
  :model_resources => ["account_id", "name", "count"]
}
  
ACTIVITIES = {
  "ticket_activity_last_10_days" => ["Helpdesk::Ticket"],    
  "forum_activity_last_10_days" => ["ForumCategory" "Forum", "Topic", "Post"],
  "solution_activity_last_10_days" => ["Solution::Article"],
}

USER_AGENT = "Freshdesk"

S3_BUCKET = "freshdesk_account_metrics"


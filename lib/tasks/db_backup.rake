BACKUP_TABLES = "affiliate_discounts affiliate_discount_mappings global_blacklisted_ips google_domains subscription_addons subscription_addon_mappings subscription_plan_addons subscription_affiliates subscription_announcements subscription_plans whitelist_users delayed_jobs social_facebook_pages domain_mappings shard_mappings"
namespace :database do
  desc "This takes backup of global database tables and puts in s3"
  task :global_backup => :environment do 
    include Helpdesk::S3::Util
     mysql_database = "helpkit"
     mysql_user = "s3backup"
     mysql_host = "fdprodshard1slave.c6mwxinbic44.us-east-1.rds.amazonaws.com"
     mysql_password = "DbFnSt02#"
      sname=Time.now.to_s.split(" ")[0]
      dump_file="#{Rails.root}/log/global_tables_#{sname}.sql"
      cmd = "mysqldump -u #{mysql_user} -p'#{mysql_password}' -h #{mysql_host} --single-transaction #{mysql_database} #{BACKUP_TABLES}"
      cmd += "  > #{dump_file}"
      puts "cmd ---> #{cmd}"
      puts "Dump starts @ #{Time.now}"
      system(cmd)
      puts "Dump Ends @ #{Time.now}"  
    push_to_s3(dump_file)
    delete_files(dump_file)
  end  
end

def push_to_s3(dump_file)
   date=Time.now.to_s.split(" ")[0]
   AwsWrapper::S3Object.store(File.basename(dump_file),open(dump_file),"global_db_backups")
   deliver_confirmation_mailer(date)
end

def delete_files(dump_file)
    File.delete("#{dump_file}")
end


def deliver_confirmation_mailer(date)
  FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
    {
      :subject => "global_db_backup to s3 completed - #{date}",
      :recipients => "pradeep.t@freshdesk.com",
      :additional_info  => { :backup_tables => BACKUP_TABLES}
    }
  )
end

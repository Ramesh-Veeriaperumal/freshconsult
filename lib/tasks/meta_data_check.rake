
# Runs in non global pod.To check for meta data consistency.

namespace :meta_data_check do
  desc "This task checks for data consistency among global pod,non global pod for newly created accounts"
  task :data_consistency_check => :environment do |task|
    if Fdadmin::APICalls.non_global_pods?
      MetaDataCheck::MetaDataCheckMethods.accounts_data
    else
      puts "Task failed -- Please make sure this task is run in non global pod"
    end
  end
end
namespace :dev_test do
  desc "Run faster tests in development machines"

  task :single_file => :environment do
    $env_loaded = true
    $local_dev_testing = true
    $clean_db = ENV["CLEAN_DB"].present? ? ENV["CLEAN_DB"].to_bool : true

    test_file_arg = ENV["TEST_FILE"]
    test_file = Rails.root.join(test_file_arg)
    
    puts "*" * 40
    puts "Starting the test for the file - #{test_file}"
    puts "*" * 40

    require test_file
  end
end
desc 'Load the database and change the secret'
task :bootstrap => :environment do
  puts "Creating tables and admin user..."
  Rake::Task["db:migrate"].invoke
  
  puts "Changing secret in environment.rb..."
  new_secret = Rails.version < '2.2' ? Rails::SecretKeyGenerator.new('Helpdesk').generate_secret : ActiveSupport::SecureRandom.hex(64)
  config_file_name = File.join(RAILS_ROOT, 'config', 'environment.rb')
  config_file_data = File.read(config_file_name)
  File.open(config_file_name, 'w') do |file|
    file.write(config_file_data.sub('c363a47eb3d9cae948c7bb2beb216c5770dfd309c6807e70a965940f9541eb5061b8bc6486795afe049f060a1477e6812dbc346f322189dc934e43993aba58f4', new_secret))
  end
  
  puts "All done!"
end

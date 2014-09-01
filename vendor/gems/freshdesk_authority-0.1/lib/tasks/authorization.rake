namespace :authority do
  task :purge => :environment do
    keeper = Authority::Bookkeeper.new('privileges.yml')
    keeper.purge
  end
end
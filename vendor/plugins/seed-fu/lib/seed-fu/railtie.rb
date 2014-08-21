module SeedFu
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/seed_fu.rake"
    end
  end
end
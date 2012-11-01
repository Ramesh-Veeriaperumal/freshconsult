namespace :sla do
  desc 'Check for SLA violation and trigger emails..'
  task :escalate => :environment do
    unless  Rails.env.staging?
      sla = RakeTasks::Sla.new
      sla.run
    end
  end
end


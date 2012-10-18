namespace :freshdesk_sphinx do
  task :delta  => :environment do
  	system("indexer --config #{RAILS_ROOT}/config/#{Rails.env}.sphinx.conf helpdesk_ticket_delta --rotate")
  	system("indexer --config #{RAILS_ROOT}/config/#{Rails.env}.sphinx.conf customer_core --rotate")
  	system("indexer --config #{RAILS_ROOT}/config/#{Rails.env}.sphinx.conf solution_article_core --rotate")
  	system("indexer --config #{RAILS_ROOT}/config/#{Rails.env}.sphinx.conf topic_core --rotate")
  	system("indexer --config #{RAILS_ROOT}/config/#{Rails.env}.sphinx.conf user_core --rotate")
  end

  task :index  => :environment do
  	system("indexer --config #{RAILS_ROOT}/config/#{Rails.env}.sphinx.conf helpdesk_ticket_core --rotate")
  end
end
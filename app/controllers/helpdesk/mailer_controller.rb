
class Helpdesk::MailerController < ApplicationController

  def fetch
    puts "MAILS CONTROLLER SHAN TEST"
    @config = YAML.load_file("#{RAILS_ROOT}/config/helpdesk.yml")
    puts @config
    @config = @config["EMAIL"]["incoming"][RAILS_ENV].to_options
    puts @config

    @fetcher = Fetcher.create({:receiver => Helpdesk::TicketNotifier}.merge(@config))
    puts "FETCHER CREATED"
    @fetcher.fetch
    puts "MAIL FETCHED"
  end

end

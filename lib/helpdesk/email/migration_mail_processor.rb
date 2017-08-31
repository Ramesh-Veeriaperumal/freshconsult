# encoding: UTF-8
require 'mail'
require 'timeout'
require 'net/imap'
require 'net/http/post/multipart'
require 'tzinfo'

class Helpdesk::Email::MigrationMailProcessor

  attr_accessor :imap, :uid, :tags_name, :gmail_tags, :envelope_address, :raw_eml, :custom_status, :skip_notification, :enable_outgoing

  def initialize(args={})
    initialise_attributes(args)
    self.raw_eml = fetch_raw_eml
  end

  def initialise_attributes(attributes)
    attributes.each do |name, value|
      if respond_to?("#{name}=")
        send("#{name}=", value)
      end
    end
  end

  def internal_date(uid)
    imap.uid_fetch(uid, "INTERNALDATE")[0].attr["INTERNALDATE"]
  end

  def fetch_raw_eml
    imap.uid_fetch(uid, "RFC822")[0].attr["RFC822"]
  end

  def process_email
    ticket_params = Helpdesk::EmailParser::EmailProcessor.new(raw_eml).process_mail
    ticket_params.merge! ({
      :envelope                    => "{\"to\":[\"#{envelope_address}\"]}",
      :migration_status            => get_status(imap, uid),
      :migration_internal_date     => internal_date(uid),
      :migration_tags              => tags_name,
      :migration_skip_notification => skip_notification,
      :migration_enable_outgoing   => enable_outgoing,
      :request_url                 => "EmailMigrationModule"
    })
    
    if gmail_tags
      labels = (imap.uid_fetch(uid, 'X-GM-LABELS').first.attr["X-GM-LABELS"]) || []
      labels.each_with_index do |flag, index|
        if flag.is_a? Symbol
          flag = flag.to_s
        end
        ticket_params[:migration_tags] << flag if flag.present?
      end
    end
    ticket_params[:migration_tags] << "Imported"
    ticket_params[:migration_tags] = ticket_params[:migration_tags].to_json
    mailbox_log "Process Email Params : #{ticket_params.inspect}"
    ticket_params
  end

  def get_status(imap, uid)
    return custom_status if custom_status.present?
    flags = imap.uid_fetch(uid, 'FLAGS').first.attr["FLAGS"]
    flags.include?(:Seen) ? 5 : 2
  rescue Exception => e
    2
  end

  def mailbox_log msg
    puts "#{Time.now.utc} - #{Thread.current.object_id} - MigrationMailProcessor - #{msg} "
    Rails.logger.info "#{Time.now.utc} - #{Thread.current.object_id} - MigrationMailProcessor - #{msg} "
  end

end
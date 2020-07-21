require 'timeout'
require 'net/imap'

include Redis::RedisKeys
include Redis::OthersRedis

module Helpdesk::Email::Migrate
  class MailProcessor

    attr_accessor :imap, :uid, :tags_name, :gmail_tags, :envelope_address, :raw_eml, :custom_status, :skip_notification, :enable_outgoing,
                  :notify_email, :account_id, :email_config_id 

    def initialize(args={})
      initialise_attributes(args)
      self.raw_eml ||= fetch_raw_eml
    end

    def initialise_attributes(attributes)
      attributes.each do |name, value|
        if respond_to?("#{name}=")
          safe_send("#{name}=", value)
        end
      end
    end

    def process
      tkt_params = process_email
      return {} if duplicate_email?(tkt_params)
      response = Helpdesk::ProcessEmail.new(tkt_params.with_indifferent_access).perform
      save_ticket_info(tkt_params)
      mailbox_log "Email is been processed successfully, ticket display id : #{response[:display_id]},  ticket id : #{response[:ticket_id]}, note id : #{response[:note_id]} "
      response
    end

    def fetch_raw_eml
      imap.uid_fetch(uid, "RFC822")[0].attr["RFC822"]
    end

    def process_email
      email_processor = Helpdesk::EmailParser::EmailProcessor.new(raw_eml)
      tkt_params = email_processor.process_mail
      tkt_params.merge! ({
        :envelope                    => "{\"to\":[\"#{envelope_address}\"]}",
        :migration_status            => get_status(imap, uid),
        :migration_internal_date     => email_processor.processed_mail.date,
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
          tkt_params[:migration_tags] << flag if flag.present?
        end
      end
      tkt_params[:migration_tags] << "Imported"
      tkt_params[:migration_tags] = tkt_params[:migration_tags].to_json
      mailbox_log "Process Email Params : #{tkt_params.inspect}"
      tkt_params
    end

    def get_status(imap, uid)
      return custom_status if custom_status.present?
      flags = imap.uid_fetch(uid, 'FLAGS').first.attr["FLAGS"]
      flags.include?(:Seen) ? 5 : 2
    rescue Exception => e
      2
    end

    def save_ticket_info(tkt_params)
      set_others_redis_key(message_key(tkt_params[:message_id]), headers_json(tkt_params), 86400*7) unless tkt_params[:message_id].nil?
    end

    def get_ticket_info(msg_id)
      get_others_redis_key(message_key(msg_id)) unless msg_id.nil?
    end

    def message_key(message_id)
      MIGRATED_EMAIL_TICKET_ID % {:account_id => account_id, :message_id => message_id, :email_config_id=>email_config_id}
    end

    def duplicate_email?(tkt_params)
      value = get_ticket_info(tkt_params[:message_id])
      if value.present? &&  value == headers_json(tkt_params)
        subject = "MailProcessor :: Duplicate Email for account_id #{account_id}"
        msg = "Duplicate Email in account_id #{account_id}, email_config_id #{email_config_id} . Saved data : #{value}"
        Rails.logger.debug msg
        Helpdesk::Email::Migrate::Mailer.send_mail(notify_email, msg)
        true
      end
    end

    def headers_json(ticket_params)
      {"from" => ticket_params[:from], "to" => ticket_params[:to], "subject" => ticket_params[:subject], "message_id" => ticket_params[:message_id], "date"=>ticket_params[:internal_date]}.to_json
    end


    def mailbox_log msg
      Rails.logger.info "#{Time.now.utc} - #{Thread.current.object_id} - MigrateMailProcessor - #{msg} "
    end
  end
end

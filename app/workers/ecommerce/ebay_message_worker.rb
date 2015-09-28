module Ecommerce
  class EbayMessageWorker < BaseWorker
    sidekiq_options :queue => :ebay_message_worker, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(args)
      begin
        msg_performer = Ecommerce::Ebay::Message.new(args)
        return if msg_performer.note.blank? 
        msg_performer.process_sent_messages
        Rails.logger.debug "Message processed with params #{args} at time #{msg_performer.end_time}"
      rescue Exception => e
        Rails.logger.debug "ebay_message_worker::ERROR  => #{e.message}\n#{e.backtrace.join("\n\t")}"
      end
    end
  end
end

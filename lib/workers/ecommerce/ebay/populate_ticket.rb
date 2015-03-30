class Workers::Ecommerce::Ebay::PopulateTicket
  extend Resque::AroundPerform 

  @queue = 'populate_ebay_ticket'
  class << self

    include Ecommerce::Ebay::Util
    include Ecommerce::Constants

    def perform args
      begin      
        if args[:retry_count].present?
          return unless args[:retry_count] < EBAY_MAXIMUM_RETRY
        end

        account = Account.current
        ticket = account.tickets.find_by_id(args[:ticket_id])
        item_id = ticket.ebay_item_id
        categories = {}
        ebay_acc = account.ebay_accounts.find_by_email_config_id(ticket.email_config_id)
        return if ebay_acc.blank?

        obj = Ecommerce::Ebay::Api.new(ebay_acc.id)
        unless ticket.ebay_item.present?
          messages = obj.make_call(:parent_message_id)
          msg_id = fetch_message_id(messages, ticket) if messages
          ebay_item = ticket.build_ebay_item( :item_id => item_id,:user_id => ticket.requester_id, :message_id => msg_id, 
                                           :ebay_acc_id => ebay_acc.id ) 
          ebay_item.save! unless msg_id.blank?
        end

        categories = obj.make_call(:item_details,{:item_id => item_id}) unless item_id.blank?

        tag_ticket(categories, ticket, ebay_acc) if categories
        handle_retry(args) if obj.instance_variable_get(:@retry) 
      rescue Exception => e
        Rails.logger.debug "PopulateTicket::ERROR  => #{e.message}, #{e.backtrace}"
      end
    end

    private
      def handle_retry(args)
        args[:retry_count] = args[:retry_count].to_i + 1
        Resque.enqueue_in(EBAY_SCHEDULE_AFTER, Workers::Ecommerce::Ebay::PopulateTicket, args)
      end

  end

  
end

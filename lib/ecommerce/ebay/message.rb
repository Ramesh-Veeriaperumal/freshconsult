class Ecommerce::Ebay::Message

  include Ecommerce::Ebay::Util

  attr_reader :note, :end_time

  def initialize(args)
    @account = ::Account.current
    @ebay_account = @account.ebay_accounts.find_by_id(args["ebay_account_id"])
    @start_time = args["start_time"]
    @end_time = Time.now.utc
    @ticket = @account.tickets.find_by_id(args["ticket_id"])
    @note = @account.notes.find_by_id(args["note_id"])
  end

  def process_sent_messages
    sent_messages = []
    sent_messages = sent_folder_messages(@ebay_account.id ,@start_time.to_time, @end_time)
    unless sent_messages.blank?
      sent_messages.reverse.each do |sent_message|
        is_match = match(sent_message)
        break if is_match and update_message_id(sent_message[:external_message_id])
      end
    end
  end

  def update_message_id(msg_id)
    @note.ebay_question.message_id = msg_id
    @note.ebay_question.save
  end


  def match(msg)
    if @ticket.ebay_question.item_id.blank? 
      return false if  msg[:item_id].present?
      subject_external_id_match(msg)
    else
      return false if  msg[:item_id].blank?
      ( subject_external_id_match(msg) and @ticket.ebay_question.item_id == msg[:item_id] )
    end
  end

  def subject_external_id_match(msg)
    (@ticket.requester.external_id.gsub("#{EBAY_PREFIX}-","") == msg[:send_to_name] and @ticket.subject == msg[:subject].gsub(EBAY_SUBJECT_REPLY, ''))      
  end

end
class Ecommerce::Ebay::Processor

  include Ecommerce::Ebay::Util

  attr_reader :ebay_account,:notification_user,:notification_subject,:notification_item_id

  def initialize(args)
    @account = ::Account.current
    @ebay_account = @account.ebay_accounts.find_by_external_account_id(args["body"]["EIASToken"])
    @notification_user = fetch_user(args["body"]["Messages"]["Message"]["Sender"])
    @notification_subject = args["body"]["Messages"]["Message"]["Subject"].gsub(EBAY_SUBJECT_REPLY, '')
    @notification_body = beautify_html(args["body"]["Messages"]["Message"]["Text"])
    @notification_msg_id = args["body"]["Messages"]["Message"]["ExternalMessageID"]
    @notification_item_id = args["body"]["Messages"]["Message"]["ItemID"]
  end

  def fetch_user(user_id)
    user = @account.all_users.find_by_external_id(ebay_user(user_id))
    unless user 
      user = @account.contacts.new
      user.active = true
      user.signup!({ :user => { :name => user_id, :external_id => ebay_user(user_id) }}, nil , false)
      tag_ecommerce_user(user, @ebay_account.name)
    end
    user
  end

  def thread_exists(ticket)
    create_note(ticket,@notification_body, @notification_user, @notification_msg_id, @notification_item_id)
    check_sent_messages_folder
  end

  def thread_not_exists
    check_sent_messages_folder
    ticket = check_parent_ticket(@notification_user.id, @notification_subject, @notification_item_id)
    ticket ? create_note(ticket, @notification_body, @notification_user, @notification_msg_id, @notification_item_id) : 
            create_ticket(@notification_subject, @notification_body, @notification_user, @notification_msg_id, @notification_item_id) #create ticket with the notiication
  end

  def check_parent_ticket(user_id, subject, item_id)
    tkt_ids = if item_id  
      @ebay_account.ebay_questions.fetch_with_item_id_user_id(item_id, user_id).pluck(:questionable_id)
    else
      @ebay_account.ebay_questions.fetch_with_user_id(user_id).pluck(:questionable_id)
    end
    match_ticket_subject(tkt_ids, subject) if tkt_ids.any?
  end

  def create_sent_message(sent_message, user)
    full_msg = fetch_message(sent_message[:external_message_id])
    if full_msg and full_msg[:messages]
      full_txt_msg = beautify_html(full_msg[:messages][:message][:text])
      create_ticket(sent_message[:subject], full_txt_msg, user,sent_message[:external_message_id], sent_message[:item_id], Helpdesk::Ticketfields::TicketStatus::CLOSED) 
    end
  end

  def check_sent_messages_folder  
    sent_messages = []
    sent_messages = fetch_user_sent_messages
    unless sent_messages.blank?
      sent_messages.reverse.each do |sent_message|
        user = fetch_user(sent_message[:send_to_name])
        ticket = check_parent_ticket(user.id, sent_message[:subject].gsub(EBAY_SUBJECT_REPLY, ''), sent_message[:item_id])
        next unless ticket.blank?
        create_sent_message(sent_message, user)
      end
    end
  end

  def create_ticket(subject, body, requester,message_id, item_id, status = nil )
    return if requester.blocked?
    ticket = nil
    ActiveRecord::Base.transaction do
      ticket = @account.tickets.build(
            :subject => subject.gsub(EBAY_SUBJECT_REPLY, ''),
            :requester => requester,
            :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:ecommerce],
            :ticket_body_attributes => {
              :description_html => body
             },
            :product_id => @ebay_account.product_id,
            :group_id => @ebay_account.group_id
        )
      ticket.spam = true if requester.deleted?
      ticket.status = status if status.present?
      ticket.build_ebay_question(:user_id => requester.id, :item_id => item_id, :ebay_account_id => @ebay_account.id, :account_id => @account.id, :message_id => message_id)
      ticket.save_ticket
      raise ActiveRecord::Rollback if ticket.ebay_question.new_record?
    end
    add_tags(ticket,item_id) unless ticket.new_record?
  end

  def create_note(ticket, body, requester,message_id, item_id )
    ActiveRecord::Base.transaction do
      note = ticket.notes.build(
          :note_body_attributes => {
            :body_html => body
          },
          :incoming => true,
          :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["ecommerce"],
          :account_id => @account.id,
          :user => requester,
          :private => false
        )
      requester.make_current
      note.build_ebay_question(:user_id => requester.id, :item_id => item_id, :ebay_account_id => @ebay_account.id, :message_id => message_id)
      note.ebay_question.account_id = @account.id
      note.save_note
      raise ActiveRecord::Rollback if note.ebay_question.new_record?
    end
  end

  def fetch_user_sent_messages
    end_time = Time.now
    sent_messages = sent_folder_messages(@ebay_account.id, @ebay_account.last_sync_time, end_time) 
    @ebay_account.update_last_sync_time(end_time) unless sent_messages.blank?
    sent_messages
  end

  def fetch_message(ext_msg_id)
    Ecommerce::Ebay::Api.new({ :ebay_account_id => @ebay_account.id}).make_ebay_api_call(:fetch_message_by_id,:external_message_id => ext_msg_id, :detail_level => "messages")
  end

  def beautify_html(text)
    text=text.gsub("<![CDATA[", "").gsub("]]>", "")
    Nokogiri::HTML(text).to_html.delete('\\"').delete("\n")
  end

  def match_ticket_subject(ticket_ids, subject)
    tickets = @account.tickets.where("id in (?)", ticket_ids).all
    tickets.each do |tkt|
      return tkt if subject == tkt.subject
    end
    nil
  end

  def add_tags(ticket,item_id)
    tag_names = [] 
    tag_names.push(EBAY_TAG, @ebay_account.name) 
    if item_id
      item_details = Ecommerce::Ebay::Api.new({:ebay_account_id => @ebay_account.id}).make_ebay_api_call(:item_details, :item_id => item_id, :detail_level => "item_description" )
      item_details[:item][:primary_category][:category_name].split(":").map{|category| tag_names.push(category)} if item_details and item_details[:item]
    end
    tag_names.each do |tag_string|
      tag = @account.tags.find_by_name(tag_string) || @account.tags.new(:name => tag_string)
      ticket.tags << tag
    end
  end

end
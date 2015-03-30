module Ecommerce::Ebay::Util
  include Ecommerce::Constants

  def ebay_parent_ticket(email,subject, email_config_id)
    account = Account.current
    ebay_account = account.ebay_accounts.find_by_email_config_id(email_config_id)
    user = account.user_emails.user_for_email(email) 
    subject = subject.gsub(EBAY_SUBJECT_REPLY, '')
    item_id = parse_item_id_from_subject(subject)
    if item_id 
      tkt_ids = ebay_account.ebay_items.fetch_with_item_id_user_id(item_id, user.id).pluck(:ticket_id)
    else
      tkt_ids = ebay_account.ebay_items.fetch_with_user_id(user.id).pluck(:ticket_id)
    end
    Account.current.tickets.ebay_tickets(tkt_ids, subject).first if tkt_ids.any?
  end

  def parse_item_id_from_subject(subject)
    $1 if subject =~ /\#(\d+)/
  end

  def fetch_message_id(messages, ticket)
    msg_id, ebay_user_id = parse_message_id(messages[:member_message][:member_message_exchange], ticket) if messages and messages[:member_message].present?
    update_external_id(ticket.requester, ebay_user_id) if ebay_user_id.present?
    msg_id
  end
 
  def parse_message_id(messages, ticket)
    msg_id, ebay_user_id = nil, nil
    Array.wrap(messages).each do |msg|
      msg_id = msg[:question][:message_id] if msg[:question][:subject].gsub(EBAY_SUBJECT_REPLY, '').downcase == ticket.subject.downcase
      if msg_id.present?
        ebay_user_id = msg[:question][:sender_id] 
        break
      end
    end
    [msg_id, ebay_user_id]
  end

  def update_external_id(user, ext_id)
    user.user_external_id = ext_id
    user.save
  end

  def tag_ticket(item_details, ticket, ecom_acc)
    tag_names = (item_details[:item] and item_details[:item][:primary_category]) ? 
                        item_details[:item][:primary_category][:category_name].split(":") : []

    tag_names.push(EBAY_TAG, ecom_acc.name) 
    tag_names.each do |tag_string|
      tag = Account.current.tags.find_by_name(tag_string) || Account.current.tags.new(:name => tag_string)
      ticket.tags << tag
    end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
  end

  def account_exists? id
    Account.current.ebay_accounts.map(&:external_account_id).include? id 
  end

end
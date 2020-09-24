class Helpdesk::BulkReplyTickets
  
  include CloudFilesHelper
  include Conversations::Twitter
  include Facebook::Constants
  include Facebook::TicketActions::Util
  include Social::Util
  attr_accessor :params, :tickets, :attachments, :inline_images_clone

  DEFAULT_NOTE_SOURCE = Helpdesk::Source.note_source_keys_by_token['email']

  def initialize(args)
    self.params = args
    self.attachments = {:new => [], :shared => [], :inline => []}
    self.tickets = []
    self.inline_images_clone = {}
    
    
    load_tickets
    load_attachments
    

    set_current_user
  end

  def act
    (tickets || []).each do |tkt|
      begin
        add_reply tkt
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        Rails.logger.error("Error while sending reply to this Ticket: #{tkt.display_id} || #{e.inspect}" )
      end
    end
  end

  def cleanup!
    # doing this to destroy the global attachments after we clone it
    attachments_to_be_destroyed = load_new_attachments.collect(&:id) + fetch_inline_attachment_records.collect(&:id)
    Helpdesk::Attachment.destroy(attachments_to_be_destroyed) if attachments_to_be_destroyed.present?
    User.reset_current_user
  end

  private

    def load_tickets
      self.tickets = Account.current.tickets.where(display_id: params[:ids]).to_a
    end

    def load_attachments
      self.attachments[:new] = load_new_attachments if new_attachments?
      self.attachments[:shared] = load_shared_attachments if shared_attachments?
      self.attachments[:inline] = load_inline_attachments if inline_attachments?
    end

    def new_attachments?
      params[:helpdesk_note]["attachments"].present?
    end

    def shared_attachments?
      params[:shared_attachments].present?
    end

    def inline_attachments?
      params[:helpdesk_note]["inline_attachment_ids"].present?
    end

    def load_new_attachments
      @attachment_records ||= Account.current.attachments.where(id: params[:helpdesk_note]["attachments"])
    end

    def load_shared_attachments
      Account.current.attachments.where(id: params[:shared_attachments])
    end

    def load_inline_attachments
      (fetch_inline_attachment_records || []).map do |attachment_obj|
        { id: attachment_obj.id, content: attachment_obj.to_io }
      end
    end

    def fetch_inline_attachment_records
      @inline_att_records ||= Account.current.attachments.where(id: params[:helpdesk_note]["inline_attachment_ids"])
    end

    def set_current_user
      if params[:account_id] and params[:current_user_id]
        user = User.find_by_account_id_and_id(params[:account_id],params[:current_user_id])
        user.make_current
       end
    end

    def add_reply ticket
      note = ticket.notes.build note_params(ticket)
      note.inline_attachment_ids = inline_images_clone[ticket.id].map do |k,image| image.id end if inline_attachments?
      note.from_email = get_from_email if params[:email_config] and params[:email_config]["reply_email"]
      note.cc_emails = note.notable.cc_email_hash[:reply_cc] if note.notable.cc_email_hash.present?
      build_attachments note
      if note.fb_note?
        association_hash = ticket.is_fb_message? ? construct_dm_hash(ticket) : construct_post_hash(ticket)
        note.build_fb_post(association_hash)
        return note.save_note
      end
      safe_send("#{note.source_name}_reply", ticket, note) if note.save_note
    end

    def get_from_email
      email_config = Account.current.email_configs.find_by_reply_email(params[:email_config]["reply_email"])
      params[:email_config]["reply_email"] if email_config
    end

    def note_params(ticket)
      params[:helpdesk_note].merge(
        source: Helpdesk::Source.ticket_note_source_mapping.fetch(ticket.source, DEFAULT_NOTE_SOURCE),
        note_body_attributes: reply_content(ticket)
      )
    end

    def reply_content ticket
      {
        :body_html => Liquid::Template.parse(clone_inline_attachment_and_replace_img(body_html,ticket.id)).render(
          'ticket' => ticket, 
          'helpdesk_name' => ticket.account.helpdesk_name
      )}
    end

    def clone_inline_attachment_and_replace_img html, ticket_id
      return body_html unless inline_attachments?
      clone_inline_attachments(ticket_id)
      replace_img_tag_src_and_data_id(html,ticket_id)
    end

    def clone_inline_attachments ticket_id
      inline_images_clone[ticket_id] = {}
      (attachments[:inline] || []).each do |a|
        image = Account.current.attachments.build({
          :description      => 'Inline_attachment',
          :content          => a[:content],
          :attachable_type  => "Account"
        })
        image.save
        inline_images_clone[ticket_id][a[:id]] = image
      end
    end

    def replace_img_tag_src_and_data_id html, ticket_id
      html_part = Nokogiri::HTML(html)
      html_part.xpath("//img[contains(@class,'inline-image')]").each do |inline|
        inline_attachment = inline_images_clone[ticket_id][inline['data-id'].to_i]
        if inline_attachment
          inline.set_attribute('src', inline_attachment.inline_url)
          inline.set_attribute('data-id', inline_attachment.id) 
        end
      end
      html_part.at_css('body').inner_html.to_s
    end

    def body_html
      params[:helpdesk_note]["note_body_attributes"]["body_html"]
    end

    def build_attachments note
      build_new_attachments(note)
      build_cloud_file_attachments(note)
      # Shared attachments will be removed moving forward
      # build_shared_attachments(note)
    end

    def build_new_attachments note
      [*attachments[:new], *attachments[:shared]].each do |att|
        note.attachments.build(:content => att.to_io , :account_id => note.account_id)
      end
    end 

    def build_shared_attachments note
      (attachments[:shared] || []).each do |a|
        note.shared_attachments.build(:account_id => note.account_id,:attachment=> a )
      end
    end

    def build_cloud_file_attachments note
      attachment_builder(note, [], params[:cloud_file_attachments])
      # Used by Private API - Will be remove once cloud files are handled in falcon
      note.cloud_files.build(params[:cloud_files]) if params[:cloud_files]
    end

    def email_reply ticket, note
      #Do nothing
    end

    def facebook_reply ticket, note
      fb_page = ticket.fb_post.facebook_page
      if fb_page
        message_type = ticket.is_fb_message? ? POST_TYPE[:message] : POST_TYPE[:post]
        send_reply(fb_page, ticket, note, message_type)
      end
    end
    
    def twitter_reply ticket, note
      twt_type = ticket.tweet.tweet_type || :mention.to_s
      twitter_handle_id = params[:twitter_handle_id]
      error_message, tweet_body = get_tweet_text(twt_type, ticket, note.body.strip)
      safe_send("send_tweet_as_#{twt_type}", twitter_handle_id, ticket, note, tweet_body) unless error_message
    end
    
    def ecommerce_reply ticket,note
      ebay_question = ticket.ebay_question
      if ebay_question
        Ecommerce::Ebay::Api.new({:ebay_account_id => ticket.ebay_question.ebay_account_id}).make_ebay_api_call(:reply_to_buyer, :ticket => ticket, :note => note)
      end
    end

end

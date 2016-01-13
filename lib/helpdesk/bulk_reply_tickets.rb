class Helpdesk::BulkReplyTickets
  
  include Conversations::Twitter
  include CloudFilesHelper
  attr_accessor :params, :tickets, :attachments

  def initialize(args)
    self.params = args
    self.attachments = {:new => [], :shared => []}
    self.tickets = []
    
    
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
    Helpdesk::Attachment.destroy(params[:helpdesk_note]["attachments"]) if new_attachments?
    User.reset_current_user
  end

  private

    def load_tickets
      self.tickets = Account.current.tickets.find_all_by_display_id(params[:ids])
    end

    def load_attachments
      self.attachments[:new] = load_new_attachments if new_attachments?
      self.attachments[:shared] = load_shared_attachments if shared_attachments?
    end

    def new_attachments?
      params[:helpdesk_note]["attachments"].present?
    end

    def shared_attachments?
      params[:shared_attachments].present?
    end

    def load_new_attachments
      (fetch_attachment_records || []).map do |attachment_obj|
        io  = open attachment_obj.authenticated_s3_get_url
        if io
          def io.original_filename; base_uri.path.split('/').last.gsub("%20"," "); end
        end
        io
      end
    end

    def fetch_attachment_records
      Helpdesk::Attachment.find_all_by_id_and_account_id(params[:helpdesk_note]["attachments"], params[:account_id])
    end

    def load_shared_attachments
      Helpdesk::Attachment.find_all_by_id_and_account_id(params[:shared_attachments], params[:account_id])
    end

    def set_current_user
      if params[:account_id] and params[:current_user_id]
        user = User.find_by_account_id_and_id(params[:account_id],params[:current_user_id])
        user.make_current
       end
    end

    def add_reply ticket
      note = ticket.notes.build note_params(ticket)
      note.from_email = get_from_email if params[:email_config] and params[:email_config]["reply_email"]
      # Injecting '@skip_resource_rate_limit' instance variable to skip spam watcher
      note.instance_variable_set(:@skip_resource_rate_limit, true)
      build_attachments note
      send("#{note.source_name}_reply", ticket, note) if note.save_note
    end

    def get_from_email
      email_config = Account.current.email_configs.find_by_reply_email(params[:email_config]["reply_email"])
      params[:email_config]["reply_email"] if email_config
    end

    def note_params ticket
      params[:helpdesk_note].merge( 
                :source => Helpdesk::Note::TICKET_NOTE_SOURCE_MAPPING[ticket.source], 
                :note_body_attributes => reply_content(ticket))
    end

    def reply_content ticket
      {
        :body_html => Liquid::Template.parse(body_html).render(
          'ticket' => ticket, 
          'helpdesk_name' => ticket.portal_name
      )}
    end

    def body_html
      params[:helpdesk_note]["note_body_attributes"]["body_html"]
    end

    def build_attachments note
      build_new_attachments(note)
      build_cloud_file_attachments(note)
      build_shared_attachments(note)
    end

    def build_new_attachments note
      (attachments[:new] || []).each do |att|
        note.attachments.build(:content => att , :account_id => note.account_id)
      end
    end 

    def build_shared_attachments note
      (attachments[:shared] || []).each do |a|
        note.shared_attachments.build(:account_id => note.account_id,:attachment=> a )
      end
    end

    def build_cloud_file_attachments note
      attachment_builder(note, [], params[:cloud_file_attachments])
    end

    def email_reply ticket, note
      #Do nothing
    end

    def facebook_reply ticket, note
      fb_page = ticket.fb_post.facebook_page
      if fb_page
        if ticket.is_fb_message?
          Facebook::Graph::Message.new(fb_page).send_reply(ticket, note)
        else
          Facebook::Core::Comment.new(fb_page, nil).send_reply(ticket, note)
        end
      end
    end
    
    def twitter_reply ticket, note
      twt_type = ticket.tweet.tweet_type || :mention.to_s
      send("send_tweet_as_#{twt_type}", ticket, note, note.body.strip)
    end

    def mobihelp_reply ticket, note
      #Do nothing
    end
    
    def ecommerce_reply ticket,note
      ebay_question = ticket.ebay_question
      if ebay_question
        Ecommerce::Ebay::Api.new({:ebay_account_id => ticket.ebay_question.ebay_account_id}).make_ebay_api_call(:reply_to_buyer, :ticket => ticket, :note => note)
      end
    end

end

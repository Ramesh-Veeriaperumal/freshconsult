class Facebook::Graph::Message
  include Facebook::Core::Util
  include Facebook::KoalaWrapper::ExceptionHandler
  include Social::Util

  def initialize(fan_page)
    @account = fan_page.account
    @fan_page = fan_page
    @rest = Koala::Facebook::API.new(fan_page.page_token)
  end

  #fetching message threads
  def fetch_messages
    threads = @rest.get_connections('me', 'conversations', {
                                      :since => @fan_page.message_since
    })

    updated_time = threads.collect {|f| f["updated_time"]}.compact.max
    create_tickets threads
    @fan_page.update_attribute(:message_since, Time.parse(updated_time).to_i) unless updated_time.blank?
  end

  #reply to a message in fb
  def send_reply(ticket, note)
    return_value = sandbox(true) {
      @fan_page = @fan_page
      thread_id =  ticket.fb_post.thread_id
      message = @rest.put_object(thread_id , 'messages',:message => note.body)
      message.symbolize_keys!

      #Create fb_post for this note
      unless message.blank?
        note.create_fb_post({
            :post_id => message[:id],
            :facebook_page_id => ticket.fb_post.facebook_page_id,
            :account_id => ticket.account_id,
            :thread_id => ticket.fb_post.thread_id,
            :msg_type =>'dm'
        })
      end
    }
    return_value
  end


  private

  def create_tickets(threads)
    threads.each do |thread|
      thread.symbolize_keys!
      fb_msg = @account.facebook_posts.latest_thread(thread[:id] , 1) ##latest thread
      previous_ticket = fb_msg.first.postable unless fb_msg.blank?
      unless previous_ticket.blank?
        if (!previous_ticket.notes.blank? && !previous_ticket.notes.latest_facebook_message.blank?)
          last_reply = previous_ticket.notes.latest_facebook_message.first
        else
          last_reply = previous_ticket
        end
      end
      if last_reply && (Time.zone.now < (last_reply.created_at + @fan_page.dm_thread_time.seconds))
        add_as_note(thread,previous_ticket)
      else
        add_as_ticket(thread)
      end
    end
  end

  def add_as_note(thread, ticket)
    thread_id = thread[:id]
    messages = thread[:messages].symbolize_keys!
    messages[:data].reverse.each do |message|
      message.symbolize_keys!
      next if @account.facebook_posts.find_by_post_id(message[:id])
      user = facebook_user(message[:from])
      message[:message] =  remove_utf8mb4_char(message[:message])
      
      @note = ticket.notes.build(
        :note_body_attributes => {
          :body_html => html_content_from_message(message)
        },
        :private => true ,
        :incoming => true,
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"],
        :account_id => @fan_page.account_id,
        :user => user,
        :created_at => Time.zone.parse(message[:created_time]),
        :fb_post_attributes => {
          :post_id => message[:id],
          :facebook_page_id => @fan_page.id,
          :account_id => @account.id,
          :msg_type =>'dm',
          :thread_id => thread_id
        }
      )
      begin
        user.make_current
        unless @note.save_note
          Rails.logger.debug "error while saving the note #{@note.errors.to_json}"
        end
      ensure
        User.reset_current_user
      end
    end
  end

  def add_as_ticket(thread)
    group_id = @fan_page.product.primary_email_config.group_id unless @fan_page.product.blank?
    messages = thread[:messages].symbolize_keys!
    messages = new_data_set messages
    message  = messages.last #Need to check last is giving the first message/or we need to find the least created date
    return unless message
    return if @account.facebook_posts.find_by_post_id(message[:id])

    message.symbolize_keys!
    requester = facebook_user(message[:from])
    message[:message] =  remove_utf8mb4_char(message[:message])

    @ticket = @account.tickets.build(
      :subject => truncate_subject(message[:message], 100),
      :requester => requester,
      :product_id => @fan_page.product_id,
      :group_id => group_id,
      :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook],
      :created_at => Time.zone.parse(message[:created_time]),
      :fb_post_attributes => {
        :post_id => message[:id],
        :facebook_page_id => @fan_page.id,
        :account_id => @account.id,
        :msg_type =>'dm',
        :thread_id => thread[:id]
      },
      :ticket_body_attributes => {
        :description_html => html_content_from_message(message)
      }
    )

    if @ticket.save_ticket
      if messages.size > 1
        add_as_note thread , @ticket
      end
    else
      Rails.logger.debug "error while saving the ticket:: #{@ticket.errors.to_json}"
    end
  end

end

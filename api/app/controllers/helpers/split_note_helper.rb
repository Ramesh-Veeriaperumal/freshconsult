module SplitNoteHelper
  def split_the_note
    create_ticket_from_note
    return if @new_ticket.errors.present?
    update_split_activities
    set_source_activity_type
    if Account.current.features?(:activity_revamp)
      @item.manual_publish(["update", RabbitMq::Constants::RMQ_ACTIVITIES_TICKET_KEY], [:update, { misc_changes: @item.activity_type.dup }])
    end
  end

  def create_ticket_from_note
    @new_ticket = scoper.build(ticket_attributes)
    @new_ticket.account_id = Account.current.id
    move_cloud_files
    new_ticket_activity

    if @new_ticket.save_ticket
      move_attachments
      @note.remove_activity
      @note.destroy
      handle_child_fb_posts(@child_fb_note_ids) if @new_ticket.fb_post
    end
  end

  def ticket_attributes
    ticket_attributes_hash = ticket_params
    ticket_attributes_hash.merge!(shared_ownership_params) if Account.current.shared_ownership_enabled?
    if @note.tweet.present?
      @note.tweet.destroy
      ticket_attributes_hash.merge!(twitter_params)
    elsif @note.fb_post.present?
      @child_fb_note_ids = @note.fb_post.child_ids
      @note.fb_post.destroy
      ticket_attributes_hash.merge!(fb_params)
    end
    ticket_attributes_hash
  end

  def move_cloud_files
    @note.cloud_files.each do |cloud_file|
      @new_ticket.cloud_files.build(url: cloud_file.url, filename: cloud_file.filename, application_id: cloud_file.application_id)
    end
  end

  def move_attachments
    @note.attachments.update_all(attachable_type: 'Helpdesk::Ticket', attachable_id: @new_ticket.id)
    @note.inline_attachments.update_all(attachable_type: 'Inline', attachable_id: @new_ticket.id)
    @new_ticket.sqs_manual_publish
  end

  def handle_child_fb_posts(child_note_ids)
    Social::FbSplitTickets.perform_async(
      user_id: User.current.id,
      child_fb_post_ids: child_note_ids,
      comment_ticket_id: @new_ticket.id,
      source_ticket_id: @item.id
    )
  end

  def new_ticket_activity
    @new_ticket.activity_type = { type: 'ticket_split_target', source_ticket_id: [@item.display_id], source_note_id: [@note.id] }
  end

  def set_source_activity_type
    @item.activity_type = {
      type: 'ticket_split_source',
      source_ticket_id: [@item.display_id],
      target_ticket_id: [@new_ticket.display_id]
    }
  end

  def update_split_activities
    @new_ticket.create_activity(User.current, 'activities.tickets.ticket_split.long', activity_data(@item), 'activities.tickets.ticket_split.short')
    @item.create_activity(User.current, 'activities.tickets.note_split.long', activity_data(@new_ticket), 'activities.tickets.note_split.short')
  end

  def ticket_params
    company_id = @note.user.companies.map(&:id).include?(@item.company_id) ? @item.company_id : @note.user.company_id
    source = @item.source == Helpdesk::Source::OUTBOUND_EMAIL ? Helpdesk::Source::EMAIL : @item.source
    {
      subject: @item.subject,
      email: @note.user.email,
      phone: @note.user.available_number,
      priority: @item.priority,
      group_id: @item.group_id,
      email_config_id: @item.email_config_id,
      product_id: @item.product_id,
      company_id: company_id,
      status: @item.status,
      source: source,
      ticket_type: @item.ticket_type,
      cc_email: {
        fwd_emails: [],
        cc_emails: @note.cc_emails || []
      },
      ticket_body_attributes: {
        description_html: @note.body_html
      }
    }
  end

  def twitter_params
    {
      twitter_id: @note.user.twitter_id,
      tweet_attributes: {
        tweet_id: @note.tweet.tweet_id,
        twitter_handle_id: @note.tweet.twitter_handle_id,
        tweet_type: @note.tweet.tweet_type.to_s,
        stream_id: @note.tweet.stream_id
      }
    }
  end

  def shared_ownership_params
    {
      internal_agent_id: @item.internal_agent_id,
      internal_group_id: @item.internal_group_id
    }
  end

  def fb_params
    {
      facebook_id: @note.user.fb_profile_id,
      fb_post_attributes: {
        post_id: @note.fb_post.post_id,
        facebook_page_id: @note.fb_post.facebook_page_id,
        account_id: @note.fb_post.account_id,
        parent_id: nil,
        post_attributes: {
          can_comment: true,
          post_type: Facebook::Constants::POST_TYPE_CODE[:comment]
        }
      }
    }
  end

  def activity_data(ticket)
    {
      eval_args: {
        split_ticket_path: [
          'split_ticket_path',
          {
            ticket_id: ticket.display_id,
            subject: ticket.subject
          }
        ]
      }
    }
  end
end

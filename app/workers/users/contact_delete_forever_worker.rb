class Users::ContactDeleteForeverWorker < BaseWorker
  sidekiq_options :queue => :contact_delete_forever, :retry => 0, :backtrace => true, :failures => :exhausted
  
  attr_accessor :args

  def perform(args)
    begin
      args.symbolize_keys!
      @args     = args
      @account  = Account.current
      @user     = @account.all_contacts.where(:deleted => true).find_by_id args[:user_id]

      return if @user.blank? || @user.agent_deleted_forever?

      if @user.was_agent?
        send_event_to_central
        anonymize_data
      else
        destroy_user_tickets
        destroy_user_notes
        destroy_user_archive_tickets
        destroy_user_replies
        destroy_user_topics
        destroy_user_calls
        destroy_user
      end
    rescue Exception => e
      puts e.inspect, args.inspect
      NewRelic::Agent.notice_error(e, {:args => args})
      raise e
    end
  end

  private

    def anonymize_data
      @user.user_emails = []
      @user.email = nil
      @user.name = "Deleted Agent"
      @user.job_title = nil
      @user.second_email = nil
      @user.phone = nil
      @user.mobile = nil
      @user.twitter_id = nil
      @user.description = nil
      @user.time_zone = nil
      @user.fb_profile_id = nil
      @user.address = nil
      @user.string_uc04 = nil
      @user.unique_external_id = nil
      @user.import_id = nil
      @user.external_id = nil
      @user.string_uc01 = nil
      @user.text_uc01 = nil
      @user.string_uc02 = nil
      @user.string_uc03 = nil
      @user.string_uc05 = nil
      @user.string_uc06 = nil
      @user.crypted_password = nil
      @user.password_salt = nil
      @user.persistence_token = nil
      @user.last_login_at = nil
      @user.current_login_at = nil
      @user.last_login_ip = nil
      @user.current_login_ip = nil
      @user.login_count = nil
      @user.failed_login_count = nil
      @user.single_access_token = nil
      @user.last_seen_at = nil
      new_pref = { :agent_deleted_forever => true }
      @user.merge_preferences = { :user_preferences => new_pref }
      @user.save!
    end

    def send_event_to_central
      @user.save_deleted_user_info
      @user.central_publish_action(:destroy)
    end

    def destroy_user_tickets
      find_in_batches_and_destroy(
        @user.tickets.preload(:notes => [
          :attachments, :inline_attachments, :cloud_files, :shared_attachments, 
          :note_old_body, :user
        ])) do |ticket|
          if ticket.associated_ticket? && TicketConstants::TICKET_ASSOCIATION_TOKEN_BY_KEY[ticket.association_type] == :assoc_parent
            child_tickets = @account.tickets.where(display_id: ticket.associates)
            child_tickets.each do |child_ticket|
              ticket_reset_associations(child_ticket)
              child_ticket.destroy
            end
          end
          ticket_reset_associations(ticket)
        end
    end

    def ticket_reset_associations(ticket)
      ticket.reset_associations
      ticket.update_attributes(:association_type => nil) if ticket.tracker_ticket?
    end

    def destroy_user_notes
      find_in_batches_and_destroy(@user.notes.where(:account_id => @user.account))
    end

    def destroy_user_archive_tickets
      find_in_batches_and_destroy(@user.archive_tickets)
    end

    def destroy_user_replies
      find_in_batches_and_destroy(@user.posts)
    end

    def destroy_user_topics
      find_in_batches_and_destroy(@user.topics)
    end

    def destroy_user_calls
      find_in_batches_and_destroy(@user.freshfone_calls)
    end

    def destroy_user
      @user.destroy
    end

    def find_in_batches_and_destroy(items)
      items.find_in_batches(batch_size: 500) do |objs|
        objs.each do |obj|
          if block_given?
            yield(obj)
          end
          obj.destroy
        end
      end
    end
end
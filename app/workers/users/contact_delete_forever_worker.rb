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
        anonymize_data
        send_event_to_central
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
      @user.save!
      anonymizing_data = {
        :email => nil, :name => "Deleted Agent",
        :job_title => nil, :second_email => nil, :phone => nil, :mobile => nil, :twitter_id => nil, :description => nil, :time_zone => nil,
        :fb_profile_id => nil, :address => nil, :string_uc04 => nil, :unique_external_id => "dummyagent#{@user.id}", :import_id => nil
      }
      @user.update_attributes!(anonymizing_data)
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
      find_in_batches_and_destroy(@user.tickets.includes(:notes => [:attachments, :inline_attachments, :cloud_files, :shared_attachments, :note_old_body, :user]))
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
          obj.destroy
        end
      end
    end
end


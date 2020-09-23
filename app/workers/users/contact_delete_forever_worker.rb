class Users::ContactDeleteForeverWorker < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Utils::Freno

  sidekiq_options :queue => :contact_delete_forever, :retry => 0, :failures => :exhausted

  APPLICATION_NAME = 'ContactDeleteForeverWorker'.freeze

  attr_accessor :args

  def perform(args)
    begin
      args.symbolize_keys!
      @args     = args
      @account  = Account.current
      shard_name = ActiveRecord::Base.current_shard_selection.shard.to_s
      key = format(CONTACT_DELETE_FOREVER_KEY, shard: shard_name)

      redis_sidekiq_concurrency = get_contact_delete_forever_concurrency
      redis_val = get_others_redis_key(key)
      if redis_val.present? && redis_val.to_i >= redis_sidekiq_concurrency
        rerun_after(get_next_time, args)
        increment_others_redis(key) # Because of ensure decrement
        return
      end
      increment_others_redis(key)

      @user = @account.all_contacts.where(:deleted => true).find_by_id args[:user_id]
      return if @user.blank? || @user.agent_deleted_forever?

      # Check for any replication lag detected by Freno for the current user's shard in DB.
      lag_seconds = get_replication_lag_for_shard(APPLICATION_NAME, shard_name, 5.seconds)
      if lag_seconds > 0
        Rails.logger.debug("Warning: Freno: ContactDeleteForeverWorker: replication lag: #{lag_seconds} secs :: user:: #{args[:user_id]} shard :: #{shard_name}")
        rerun_after(lag_seconds, args)
        return
      elsif @user.was_agent?
        delete_agent_data
      else
        delete_contact_data
      end
    rescue Exception => e
      puts e.inspect, args.inspect
      NewRelic::Agent.notice_error(e, {:args => args})
      raise e
    ensure
      decrement_others_redis(key)
    end
  end

  private

    def rerun_after(lag, args)
      Users::ContactDeleteForeverWorker.perform_in(lag, args)
    end

    def delete_agent_data
      send_event_to_central
      remove_user_companies
      destroy_contact_field_data
      destroy_avatar
      anonymize_data
    end

    def delete_contact_data
      destroy_user_tickets
      destroy_user_notes
      destroy_user_archive_tickets
      destroy_user_replies
      destroy_user_topics
      destroy_user_calls
      destroy_custom_survey_results
      destroy_survey_results
      destroy_user
    end

    def remove_user_companies
      @user.companies = []
    end

    def destroy_contact_field_data
      cf = ContactFieldData.where(:account_id => @account, :user_id => @user).first
      cf.destroy if cf.present?
    end

    def destroy_avatar
      @user.avatar.destroy if @user.avatar.present?
    end

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
      @user.string_uc07 = nil
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
          :note_body, :user
        ])) do |ticket|
          if ticket.parent_ticket?
            child_tickets = @account.tickets.where(display_id: ticket.associates)
            find_in_batches_and_destroy(child_tickets) do |child|
              ticket_reset_associations(child)
            end
          end
          ticket.reload
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
      find_in_batches_and_destroy(@user.archive_tickets) {|arch_tkt| arch_tkt.shred_inline_images }
    end

    def destroy_user_replies
      find_in_batches_and_destroy(@user.posts)
    end

    def destroy_user_topics
      destroy_unpublished_spam
      find_in_batches_and_destroy(@user.topics)
    end

    def destroy_survey_results
      find_in_batches_and_destroy(@user.survey_results)
    end

    def destroy_custom_survey_results
      find_in_batches_and_destroy(@user.custom_survey_results)
    end

    def destroy_unpublished_spam
      Post::SPAM_SCOPES_DYNAMO.values.each do |scope|
        results = scope.by_user(@user.id, next_user_timestamp)
        while(results.present?)
          last = results.last.user_timestamp
          destroy_post(results)
          results = last.present? ? scope.by_user(@user.id, last) : []
        end
      end
    end

    def next_user_timestamp
      @user.id * (10 ** 17) + (Time.now - ForumSpam::UPTO).utc.to_f * (10 ** 7)
    end

    def destroy_post(posts)
      posts.each do |post|
        post.destroy_attachments
        post.destroy
      end
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
            begin
              obj.reload
            rescue
              next
            end
            yield(obj)
          end
          obj.destroy
        end
      end
    end

    def get_next_time
      max_time = (get_others_redis_key(CONTACT_DELETE_FOREVER_MAX_TIME) || 10).to_i
      min_time = (get_others_redis_key(CONTACT_DELETE_FOREVER_MIN_TIME) || 2).to_i
      if check_min_and_max_time(min_time, max_time)
        max_time = 2
        min_time = 2
      end
      from_now = rand(min_time..max_time)
      from_now.minutes.since
    end

    def get_contact_delete_forever_concurrency
      (get_others_redis_key(CONTACT_DELETE_FOREVER_CONCURRENCY) || 1).to_i
    end

    def check_min_and_max_time(min_time, max_time)
      max_time < min_time
    end
end

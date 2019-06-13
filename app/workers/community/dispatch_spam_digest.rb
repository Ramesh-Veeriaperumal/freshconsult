class Community::DispatchSpamDigest < BaseWorker

  sidekiq_options :queue => :spam_digest_mailer, :retry => 0, :failures => :exhausted

  def perform
    current_account = Account.current
    moderation_digest = HashWithIndifferentAccess.new({
                :unpublished_count => SpamCounter.elaborate_count("unpublished"),
                :spam_count => SpamCounter.elaborate_count("spam")
              })

    moderation_digest.delete(:unpublished_count) unless can_send_approval_digest?(moderation_digest)

    unless counters_blank(moderation_digest)
      Time.zone = current_account.time_zone
      current_account.forum_moderators.each do |moderator|
        SpamDigestMailer.spam_digest({
            :account => current_account,
            :recipients => moderator.email,
            :moderator => moderator.user,
            :subject => %(Topics waiting for approval in #{current_account.name} - #{Time.zone.now.strftime(Timezone::Constants::MAIL_FORMAT)}),
            :moderation_digest => moderation_digest,
            :host => current_account.full_url
          }) unless moderator.email.blank?
      end
    end
  rescue Exception => e
    Rails.logger.error "DispatchSpamDigest :: Error occured for the Account #{current_account.id} #{e.message}"
    NewRelic::Agent.notice_error(e, description: 'DispatchSpamDigest :: Error occured for the Account #{current_account.id}')
  end

  def can_send_approval_digest?(moderation_digest)
    reject_blank_values(moderation_digest[:unpublished_count]).present? ||
          (Account.current.features_included?(:moderate_all_posts) || Account.current.features_included?(:moderate_posts_with_links))
  end

  def reject_blank_values(counter)
    counter.reject { |k,v| v <= 0 }
  end

  def counters_blank(moderation_digest)
    moderation_digest.reject { |k,v| reject_blank_values(v).blank? }.blank?
  end

end
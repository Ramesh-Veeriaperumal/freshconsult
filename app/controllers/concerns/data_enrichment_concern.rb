module Concerns::DataEnrichmentConcern

  extend ActiveSupport::Concern

  included do
    after_commit :enqueue_for_data_enrichment, on: :update

    def enqueue_for_data_enrichment
      return unless Rails.env.production?
      account = Account.current
      Rails.logger.debug "******* Data Enrichment Concern account: ##{account.id}  ehawk_spam: #{account.ehawk_spam?} verified: #{account.verified?} model: #{self.class.name.underscore} condition: #{safe_send(self.class.name.underscore + "_check")} changes: #{self.previous_changes.inspect}"
      return if account.ehawk_spam? || !account.subscription.trial? || account.opt_out_analytics_enabled?
      ContactEnrichment.perform_async({:email_update => @email_update}) if safe_send(self.class.name.underscore + "_check")
    end

    private
    def account_configuration_check
      @email_update = true
      self.email_updated?
    end

    def conversion_metric_check
      # User.current check added to segregate spam score update triggered by sendgrid domain updates
      @email_update = false
      return previous_changes.key?(:spam_score) && User.current.nil?
    end
  end

end

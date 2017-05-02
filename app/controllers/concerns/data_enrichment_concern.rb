module Concerns::DataEnrichmentConcern

  extend ActiveSupport::Concern

  included do
    after_commit :enqueue_for_data_enrichment, on: :update

    def enqueue_for_data_enrichment
      account = Account.current
      return if account.ehawk_spam? || account.verified?
      ContactEnrichment.perform_async({:email_update => @email_update}) if send(self.class.name.underscore + "_check")
    end

    private
    def account_configuration_check
      @email_update = true
      self.email_updated?
    end

    def conversion_metric_check
      @email_update = false
      self.previous_changes.key?("spam_score")
    end
  end

end
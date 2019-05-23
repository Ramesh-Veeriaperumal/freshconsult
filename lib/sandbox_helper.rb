module SandboxHelper
  include Sync::Constants

  def send_error_notification(error, account)
    topic = SNS["sandbox_notification_topic"]
    subj = "Sandbox Error in Account: #{account.id}"
    message = "Sandbox failure in Account id: #{account.id}, \n#{error.message}\n#{error.backtrace.join("\n\t")}"
    DevNotification.publish(topic, subj, message.to_json)
  end

  def reindex_account(account, resync = false)
    ASSOCIATIONS_TO_REINDEX.each do |assocition_to_index|
      account.safe_send(assocition_to_index).find_each do |item|
        item.safe_send(:add_to_es_count) if item.respond_to?(:add_to_es_count, true)
      end
    end
    account.safe_send(:enable_searchv2) unless resync
    account.tags.find_in_batches(:batch_size => 300) do |tags|
      tags.map(&:sqs_manual_publish_without_feature_check)
    end if resync
  end

  def account_addition_settings_info(account_id)
    settings = {}
    Sharding.admin_select_shard_of(account_id) do
      account = Account.find(account_id)
      settings[:time_zone]           = account.time_zone
      settings[:plan_features]       = account.plan_features
      account_additional_settings    = account.account_additional_settings
      settings[:email_template]      = account_additional_settings.additional_settings[:email_template]
      settings[:supported_languages] = account_additional_settings .supported_languages
      settings
    end
  end

  def parse_email_template_data(template_diff, failed_records)
    failed_diff = {}
    template_diff.each do |association, records|
      object = Account.reflections[association.to_sym].klass.new
      model_name = object.class.name
      if failed_records.present? && failed_records[model_name].present?
        records.delete_if do |item| 
          (failed_diff[association] ||= []) << item  if failed_records[model_name].include? item['id'].to_i
        end
      end
      template_diff.delete(association) unless template_diff[association].present?
    end
    {success_diff: template_diff, failure_diff: failed_diff}
  end
end

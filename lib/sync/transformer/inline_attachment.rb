module Sync::Transformer::InlineAttachment
  include Sync::Transformer::Util
  include Sync::SqlUtil
  include Sync::Constants
  include Sync::Transformer::InlineAttachmentUtil

  def transform_helpdesk_ticket_template_data_description_html(data, _mapping_table)
    @mapping_table = _mapping_table
    transform_inline_attachment(data)
  end

  def transform_admin_canned_responses_response_content_html(data, _mapping_table)
    @mapping_table = _mapping_table
    transform_inline_attachment(data)
  end

  private

    def transform_inline_attachment(data)
      @destination_account_id = account.id
      Sharding.select_shard_of(master_account_id) do
        source_account = Account.find(master_account_id)
        attachment_ids, old_inline_urls = inline_attachment_data(data, source_account)
        copy_inline_attachments(data, attachment_ids, old_inline_urls, source_account)
      end
    end

    def copy_inline_attachments(data, attachment_ids, old_inline_urls, source_account)
      attachment_ids.each_with_index do |attachment_id, index|
        attachment = source_account.attachments.find(attachment_id)
        table = Arel::Table.new('helpdesk_attachments'.to_sym)
        arel_values = []
        columns = Helpdesk::Attachment.columns.map(&:name) - IGNORE_ASSOCIATIONS
        columns.each do |column|
          arel_values << [table[column], attachment.safe_send(column)]
        end
        arel_values << [table[:account_id], @destination_account_id]
        data = insert_attachment_in_destination_account(data, arel_values, old_inline_urls[index], attachment_id)
      end
      data
    end

    def insert_attachment_in_destination_account(data, arel_values, old_inline_url, source_attachment_id)
      Sharding.admin_select_shard_of(@destination_account_id) do
        destination_account = Account.find(@destination_account_id)
        insert_id = delete_and_insert('helpdesk_attachments', source_attachment_id, arel_values)
        attachment = destination_account.attachments.find(insert_id)
        # copy s3 attachment
        insert_mapping_table(source_attachment_id, insert_id)
        new_inline_url = attachment.inline_url
        data.gsub! old_inline_url, new_inline_url
      end
    end

    def insert_mapping_table(source_attachment_id, destination_attachment_id)
      mapping_table['Helpdesk::Attachment'] ||= {}
      mapping_table['Helpdesk::Attachment'][:id] ||= {}
      mapping_table['Helpdesk::Attachment'][:id][source_attachment_id] = destination_attachment_id
    end
end

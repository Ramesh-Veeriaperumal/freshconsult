class Sync::DataToFile::Transformer
  include Sync::DataToFile::Util
  include Sync::Transformer::VaRule
  include Sync::Transformer::InlineAttachmentUtil
  attr_accessor :mapping_table, :account, :master_account_id

  TRANSFORMATION_COLUMNS = {
    'Helpdesk::TicketField' => ['name'],
    'Helpdesk::NestedTicketField' => ['name'],
    'FlexifieldDef'               => ['name'],
    'FlexifieldDefEntry'          => ['flexifield_alias'],
    'Helpdesk::TicketTemplate'    => ['template_data', 'data_description_html'],
    'VaRule'                      => ['filter_data', 'action_data'],
    'Helpdesk::SharedAttachment'  => ['attachment_id'],
    'Admin::Skill'                => ['filter_data'],
    'Admin::CannedResponses::Response' => ['content_html'],
    'EmailNotification' => ['requester_template', 'agent_template']
  }.freeze

  INLINE_ATTACHMENT_TRANSFORMATION_COLUMNS = {
    'EmailNotification'                => ['requester_template', 'agent_template'],
    'Helpdesk::TicketTemplate'         => ['data_description_html'],
    'Admin::CannedResponses::Response' => ['content_html']
  }.freeze

  HTML_COLUMNS = {
    'Helpdesk::TicketTemplate' => ['data_description_html'],
    'Admin::CannedResponses::Response' => ['content_html'],
    'EmailNotification'                => ['requester_template', 'agent_template']
  }.freeze

  TRANSFORMATION_IDS = [
    'Helpdesk::Attachment'
  ].freeze

  def initialize(mapping_table, account = Account.current)
    @account       = account
    @mapping_table = mapping_table
    @mapping_table.keys.each do |model|
      next unless ['Account', 'Helpdesk::Attachment']
      @mapping_table[model].keys.each do |mapping_column|
        @mapping_table[model][mapping_column] = @mapping_table[model][mapping_column].invert
      end
    end
    @master_account_id = @mapping_table['Account'][:id][account.id.to_i] if mapping_table.present?
  end

  def available_column?(model, column)
    (TRANSFORMATION_COLUMNS[model.to_s] || []).include?(column)
  end

  def available_id?(model)
    TRANSFORMATION_IDS.include?(model)
  end

  ['Helpdesk::TicketField', 'Helpdesk::NestedTicketField','FlexifieldDef','FlexifieldDefEntry'].each do |model|
    TRANSFORMATION_COLUMNS[model].each do |column|
      define_method "transform_#{model.gsub('::', '').snakecase}_#{column}" do |data|
        change_custom_field_name(data)
      end
    end
  end

  def available_html_column?(model, column)
    (HTML_COLUMNS[model.to_s] || []).include?(column)
  end

  def transform_helpdesk_ticket_template_template_data(data)
    data = Hash[data.map { |k, v| [change_custom_field_name(k), v] }]
    data[:inherit_parent] = data[:inherit_parent].map { |k| change_custom_field_name(k) } if data[:inherit_parent]
    ActionController::Parameters.new(data)
  end

  def transform_admin_skill_filter_data(data)
    # Need to move va rule filter data logic to util.
    transform_va_rule_filter_data(data, mapping_table).map{|it| it.stringify_keys!}
  end

  def transform_helpdesk_shared_attachment_attachment_id(data)
    apply_id_mapping(data, get_mapping_data('Helpdesk::Attachment', mapping_table)).to_i
  end

  TRANSFORMATION_IDS.each do |model|
    define_method "transform_#{model.gsub('::', '').snakecase}_id" do |data|
      apply_id_mapping(data, get_mapping_data(model, mapping_table)).to_i
    end
  end

  def transfor_helpdesk_attachment_attachable_id(data, object)
    data = master_account_id if data && object.read_attribute('attachable_type') == 'Account'
    data
  end

  def change_custom_field_name(data)
    data = "#{Regexp.last_match(1)}_#{master_account_id}" if data =~ /(.*)_#{account.id}/
    data
  end

  INLINE_ATTACHMENT_TRANSFORMATION_COLUMNS.each do |model, columns|
    columns.each do |column|
      define_method "transform_#{model.gsub('::', '').snakecase}_#{column}" do |data|
        transform_inline_attachment(data)
      end
    end
  end

  def transform_inline_attachment(data, _mapping_table = {})
    attachment_ids, old_inline_urls = inline_attachment_data(data, @account)
    replace_existing_inline_url(data, attachment_ids, old_inline_urls)
  end

  # Need to check
  HTML_COLUMNS.each do |model, columns|
    columns.each do |column|
      define_method "trim_#{model.gsub('::', '').snakecase}_#{column}" do |data|
        # ****************** ALERT ***********************************#
        # Rails.logger.info('# ****************** ALERT Need to fix ***********************************#')
        # if data && data.rindex("\n") && (data.rindex("\n")+1) == data.length # Testing.
        #   data = data.slice!(data.rindex("\n"), 1)
        # end
        data
      end
    end
  end

  private

    def replace_existing_inline_url(data, attachment_ids, old_inline_urls)
      attachment_ids.each_with_index do |attachment_id, index|
        existing_attachment_id = @mapping_table['Helpdesk::Attachment'][:id][attachment_id] if attachment_mapping_exists?
        data = existing_inline_url(existing_attachment_id, data, old_inline_urls[index]) if existing_attachment_id
      end
      data
    end

    def attachment_mapping_exists?
      @mapping_table['Helpdesk::Attachment'] && @mapping_table['Helpdesk::Attachment'][:id]
    end

    def existing_inline_url(existing_attachment_id, data, old_inline_url)
      Sharding.admin_select_shard_of(@master_account_id) do
        destination_account = Account.find(@master_account_id).make_current
        attachment = destination_account.attachments.find(existing_attachment_id)
        existing_url = attachment.inline_url
        data.gsub! old_inline_url, existing_url
      end
    ensure
      @account.make_current
    end
end

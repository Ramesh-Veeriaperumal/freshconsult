class Sync::DataToFile::Transformer
  include Sync::DataToFile::Util
  include Sync::Transformer::VaRule
  include Sync::Transformer::InlineAttachmentUtil
  include Sync::Transformer::SlaPolicy
  attr_accessor :mapping_table, :account, :master_account_id

  DEFAULT_SANDBOX_ID_OFFSET = 1000000000000.freeze

  TRANSFORMATION_COLUMNS = {
    'Helpdesk::TicketField'       => [['name']],
    'Helpdesk::NestedTicketField' => [['name']],
    'FlexifieldDef'               => [['name']],
    'FlexifieldDefEntry'          => [['flexifield_alias']],
    'Helpdesk::TicketTemplate'    => [['template_data', 'data_description_html']],
    'VaRule'                      => [['filter_data', 'action_data', 'condition_data', 'last_updated_by']],
    'Helpdesk::SharedAttachment'  => [['attachment_id'], lambda { |transformer, object| !transformer.skip_transformation?(object.read_attribute('attachment_id'), object.class.to_s) }],
    'Admin::Skill'                => [['filter_data']],
    'Admin::CannedResponses::Response' => [['content_html']],
    'EmailNotification'           => [['requester_template', 'agent_template']],
    'Helpdesk::Attachment'        => [['attachable_id'], lambda { |transformer, object| object.read_attribute('attachable_type') == 'Account' }],
    'Helpdesk::SlaPolicy'         => [['conditions', 'escalations']]
  }

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

  SKIP_TRANSFORMATION = [
    'Helpdesk::TicketStatus'
  ].freeze

  TICKET_TEMPLATE_KEY_MODEL_MAPPING = {
    'responder_id' => 'User',
    'product_id'   => 'Product',
    'group_id'     => 'Group'
  }.freeze

  def initialize(mapping_table, master_account_id, account = Account.current)
    @account       = account
    @master_account_id = master_account_id
    @mapping_table = mapping_table
    @mapping_table.keys.each do |model|
      next unless ['Account', 'Helpdesk::Attachment']
      @mapping_table[model].keys.each do |mapping_column|
        @mapping_table[model][mapping_column] = @mapping_table[model][mapping_column].invert
      end
    end
    master_account_shard = ShardMapping.fetch_by_account_id(@master_account_id)
    @offset_value = Integer(SANDBOX_ID_OFFSET[master_account_shard.shard_name] || DEFAULT_SANDBOX_ID_OFFSET)
    @current_shard = ActiveRecord::Base.current_shard_selection.shard.to_s
    @autoincrement_id = AutoIncrementId[@current_shard].to_i
  end

  def available_column?(model, column, object)
    transformation_column = (TRANSFORMATION_COLUMNS[model.to_s] || [[]])
    transformation_column[0].include?(column) && (!transformation_column[1].present? || transformation_column[1].call(self, object))
  end

  def available_id?(model)
    TRANSFORMATION_IDS.include?(model)
  end

  def skip_transformation?(data, model = '')
    Sync::Logger.log "Inside skip_transformation, model: #{model}, #{SKIP_TRANSFORMATION.include?(model)}, data: #{data.to_i}, autoincrement_id: #{@autoincrement_id}, #{data.to_i >= @autoincrement_id}"
    set_shard_and_autoincrement_id
    SKIP_TRANSFORMATION.include?(model) || data.to_i >= @autoincrement_id
  end

  ['Helpdesk::TicketField', 'Helpdesk::NestedTicketField','FlexifieldDef','FlexifieldDefEntry'].each do |model|
    TRANSFORMATION_COLUMNS[model].each do |column|
      define_method "transform_#{model.gsub('::', '').snakecase}_#{column[0]}" do |data|
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
    TICKET_TEMPLATE_KEY_MODEL_MAPPING.each do |key, model|
      if data[key].present?
        data[key] = apply_id_mapping(data[key], {})
      end
    end
    ActionController::Parameters.new(data)
  end

  def transform_admin_skill_filter_data(data)
    # Need to move va rule filter data logic to util.
    transform_va_rule_filter_data(data)
  end

  def transform_helpdesk_shared_attachment_attachment_id(data)
    apply_id_mapping(data)
  end

  TRANSFORMATION_IDS.each do |model|
    define_method "transform_#{model.gsub('::', '').snakecase}_id" do |data|
      apply_id_mapping(data)
    end
  end

  def transform_helpdesk_attachment_attachable_id(data)
    data = master_account_id if data
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

  def calc_id(val, reverse = false)
    new_val = reverse ? val.to_i + @offset_value : val.to_i - @offset_value
    val.is_a?(String) ? new_val.to_s : new_val
  end    

  private

    def replace_existing_inline_url(data, attachment_ids, old_inline_urls)
      attachment_ids.each_with_index do |attachment_id, index|
        existing_attachment_id = apply_id_mapping(attachment_id)
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
        attachment = destination_account.attachments.find_by_id(existing_attachment_id)
        data.gsub! old_inline_url, attachment.inline_url if data && attachment
      end
      data
    ensure
      @account.make_current
    end

    def set_shard_and_autoincrement_id
      if @current_shard != ActiveRecord::Base.current_shard_selection.shard.to_s
        @current_shard = ActiveRecord::Base.current_shard_selection.shard.to_s
        @autoincrement_id = AutoIncrementId[@current_shard].to_i
        Sync::Logger.log "current_shard changed, current_shard: #{@current_shard.inspect}, @autoincrement_id: #{@autoincrement_id}"
      end
    end
end

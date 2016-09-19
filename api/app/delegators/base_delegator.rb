class BaseDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options, :draft_attachments

  validate :validate_draft_attachments, :validate_attachment_size, if: -> { @attachment_ids }

  def initialize(record, options={})
    super(record)
    @error_options = {}
    @attachment_ids = options[:attachment_ids]
    retrieve_draft_attachments if @attachment_ids
  end

  # Set true for instance_variable_set if it is part of request params.
  # Say if request params has forum_type, forum_type_set attribute will be set to true.
  def check_params_set(request_params)
    request_params.each_pair do |key, value|
      instance_variable_set("@#{key}_set", true)
    end
  end

  def attr_changed?(att, record = self)
    # changed_attributes gives a hash, that is already constructed when the attributes are assigned.
    # in Rails 3.2 changed_attributes is a Hash, hence exact strings are required.
    # Faster than using changed(changed_attributes.keys), would have been faster if changed_attributes were a HashWithIndifferentAccess
    record.changed_attributes.key? att
  end

  def validate_draft_attachments
    invalid_attachment_ids = @attachment_ids - @draft_attachments.map(&:id)
    if invalid_attachment_ids.any?
      errors[:attachment_ids] << :invalid_list
      @error_options = { attachment_ids: { list: "#{invalid_attachment_ids.join(', ')}" } }
    end
  end

  def validate_attachment_size
    all_attachments = @draft_attachments | (self.respond_to?(:attachments) ? self.attachments : [] )
    total_attachment_size = all_attachments.collect{ |a| a.content_file_size }.sum
    if total_attachment_size > attachment_size
      errors[:attachment_ids] << :'invalid_size'
      @error_options = { attachment_ids: { current_size: number_to_human_size(total_attachment_size), max_size: number_to_human_size(attachment_size) } }
    end
  end

  private

    def retrieve_draft_attachments
      @draft_attachments = Account.current.attachments.where(id: @attachment_ids, attachable_type: AttachmentConstants::STANDALONE_ATTACHMENT_TYPE)
    end

    def attachment_size
      ApiConstants::ALLOWED_ATTACHMENT_SIZE
    end
end

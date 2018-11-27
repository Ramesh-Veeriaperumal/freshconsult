class CannedResponseFolderDelegator < BaseDelegator
  include ActiveRecord::Validations
  validate :validate_folder, if: -> { @folder_id }

  def initialize(record, options = {})
    super(record, options)
    @folder_id = options[:id]
  end

  def validate_folder
    folder_ids = Account.current.canned_response_folders.editable_folder.pluck(:id)
    unless folder_ids.include?(@folder_id)
      errors[:folder_id] << I18n.t('canned_responses.errors.valid_folder_id')
    end
  end
end

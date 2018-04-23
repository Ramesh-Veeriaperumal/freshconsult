class CustomerNoteDelegator < BaseDelegator
  # validate :validate_cloud_file_ids, if: -> { @cloud_file_ids }
  # validate :validate_application_id, if: -> { cloud_files.present? }

  def initialize(record, options = {})
    super(record, options)
    # @cloud_file_ids = options[:cloud_file_ids]
    # retrieve_cloud_files if @cloud_file_ids
  end

  private

    # def retrieve_cloud_files
    #   @cloud_file_attachments = cloud_files.where(id: @cloud_file_ids)
    # end

    # def validate_application_id
    #   application_ids = cloud_files.map(&:application_id)
    #   applications = Integrations::Application.where('id IN (?)', application_ids)
    #   invalid_ids = application_ids - applications.map(&:id)
    #   if invalid_ids.any?
    #     errors[:application_id] << :invalid_list
    #     (self.error_options ||= {}).merge!(application_id: { list: invalid_ids.join(', ').to_s })
    #   end
    # end
end

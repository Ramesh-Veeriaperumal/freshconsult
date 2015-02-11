module Export::Util
  include Rails.application.routes.url_helpers

  def check_and_create_export type
    limit_data_exports type
    @data_export = Account.current.data_exports.new(
                                  :source => DataExport::EXPORT_TYPE[type.to_sym], 
                                  :user => User.current,
                                  :status => DataExport::EXPORT_STATUS[:started]
                                )
    @data_export.save
  end

  def limit_data_exports type
    acc_export = User.current.data_exports.send("#{type.to_s}_export")
    acc_export.first.destroy if acc_export.count >= DataExport::TICKET_EXPORT_LIMIT
  end

  def build_file file_string, type, format = "csv"
    file_path = generate_file_path(type, format)
    write_file(file_string, file_path)
    @data_export.file_created!
    build_attachment(file_path)
    remove_export_file(file_path)
  end

  def write_file file_string, file_path
    File.open(file_path , "wb") do |f|
      f.write(file_string)
    end
  end

  def generate_file_path type, format
    output_dir = "#{Rails.root}/tmp/export/#{Account.current.id}/#{type}" 
    FileUtils.mkdir_p output_dir
    file_path = "#{output_dir}/#{type.pluralize}-#{Time.now.strftime("%B-%d-%Y-%H:%M")}.#{format}"
    file_path
  end

  def build_attachment(file_path)
    file = File.open(file_path,  'r')
    attachment = @data_export.build_attachment(:content => file, :account_id => Account.current.id)
    attachment.save!
    @data_export.file_uploaded!
  end

  def remove_export_file(file_path)
    FileUtils.rm_f(file_path)
    @data_export.completed!
  end

  def hash_url portal_url
    Rails.application.routes.url_helpers.download_file_url(@data_export.source,
              file_hash(@data_export.id),
              host: portal_url, 
              protocol: Account.current.url_protocol
            )
  end

  def file_hash(export_id)
    file_hash = Digest::SHA1.hexdigest("#{export_id}#{Time.now.to_f}")
    @data_export.save_hash!(file_hash)
    file_hash
  end
end
module LoadInitializer

  def self.load_files( file_path, params )
    if params.is_a?(Hash)
      params.each { |k, v| self.load_files("#{file_path}/#{k}", v) }
    else # params is Array
      params.each do |file| 
        if file.is_a?(String)
          require "#{file_path}/#{file}.rb"
        else # file is Hash
          file.each { |k, v| self.load_files("#{file_path}/#{k}", v) }
        end
      end
    end
  end
end
LoadInitializer.load_files( "#{Rails.root}/lib", YAML.load_file(File.join(Rails.root, 'config', 'helpdesk_initializers.yml')) )

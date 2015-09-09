class CacheLib
  class << self
    def key(record, params)
      Digest::SHA512.hexdigest params[:controller] + params[:action] + record.inspect
    end

    def compound_key(*records, params)
      Digest::SHA512.hexdigest params[:controller] + params[:action] + records.inspect
    end
  end
end
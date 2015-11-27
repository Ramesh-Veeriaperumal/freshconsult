class CacheLib
  class << self
    def key(record, params)
      Digest::MD5.hexdigest params[:controller] + params[:action] + record.inspect
    end

    def compound_key(*records, params)
      Digest::MD5.hexdigest params[:controller] + params[:action] + records.inspect
    end
  end
end

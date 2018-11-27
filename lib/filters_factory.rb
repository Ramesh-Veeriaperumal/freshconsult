class FiltersFactory
  class << self
    SOURCE_MAPPING = {
      es_cluster: 'FilterFactory::Filter::ESCluster',
      sql: 'FilterFactory::Filter:SQL:'
    }.freeze

    SOURCES = SOURCE_MAPPING.keys

    def filterer(context, args)
      klass = fetch_klass(context)
      raise FilterFactory::Errors::UnknownQuerySourceException unless klass
      klass.new(context[:scoper], args)
    end

    private

      def fetch_klass(context)
        return unless SOURCES.include? context[:source]
        mapping = SOURCE_MAPPING[context[:source]]
        mapping ? mapping.constantize : nil
      end
  end
end

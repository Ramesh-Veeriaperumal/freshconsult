module Migration
  class Base

    attr_accessor :options

    def initialize(options = {})
      @options = options
    end

    private

      def log(text)
        Rails.logger.debug "#{Thread.current[:migration_klass]} #{text}"
      end
  end
end

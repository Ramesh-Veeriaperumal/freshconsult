# TODO:RAILS-SESSION-SHARING
module ActionController
  module Session
    class AbstractStore
      class SessionHash < Hash
        def [](key)
          load_for_read!
          super(key.to_s) || super(key)
        end
      end
    end
  end
end

module ActionDispatch
  class Flash
    class FlashHash
      include Enumerable

      def initialize #:nodoc:
        @used    = Set.new
        @closed  = false
        @flashes = {}
        @now     = nil
      end

      def [](k)
        @flashes[k]
      end

      def method_missing(m, *a, &b)
      end
    end
  end
end
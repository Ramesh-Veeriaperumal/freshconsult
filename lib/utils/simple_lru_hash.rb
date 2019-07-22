module Utils
  class SimpleLRUHash
    def initialize(max_size)
      raise ArgumentError, :max_size if max_size < 1

      @max_size = max_size
      @data     = {}
    end

    def max_size=(size)
      raise ArgumentError, :max_size if size < 1

      @max_size = size
      if @max_size < @data.size
        @data.keys[0..@max_size - @data.size].each do |k|
          @data.delete(k)
        end
      end
    end

    def [](key)
      found = true
      value = @data.delete(key) { found = false }
      @data[key] = value if found
    end

    def []=(key, val)
      @data.delete(key)
      @data.delete(@data.first[0]) if (@data.length + 1) > @max_size
      @data[key] = val
    end

    def each
      @data.reverse_each do |pair|
        yield pair
      end
    end

    def to_a
      @data.to_a.reverse
    end

    def delete(key)
      @data.delete(key)
    end

    def clear
      @data.clear
    end

    def count
      @data.count
    end
  end
end

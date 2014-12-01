if RUBY_VERSION >= '2.1'
  # respond_to? method returns true for protected methods in mri 1.9 but false in mri 2.1

  #https://github.com/arsduo/koala/issues/346
  require 'net/http'
  module HTTPResponseDecodeContentOverride
    def initialize(h,c,m)
      super(h,c,m)
      @decode_content = true
    end
    def body
      res = super
      if self['content-length'] && res && res.respond_to?(:bytesize)
        self['content-length']= res.bytesize
      end
      res
    end
  end
  module Net
    class HTTPResponse
      prepend HTTPResponseDecodeContentOverride
    end
  end
end
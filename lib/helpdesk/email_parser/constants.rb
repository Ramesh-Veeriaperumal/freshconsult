module Helpdesk::EmailParser::Constants

  ENCODING_MAPPING = { "GB2312"         => "GB18030",
                       "GBK"            => "GB18030",
                       "KS_C_5601-1987" => "CP949",
                       "MS949"          => "CP949"
                       }

  #Mime type constants
	TEXT_MIME_TYPE = "text/plain"
	HTML_MIME_TYPE = "text/html"
	RFC822_MIME_TYPE = "message/rfc822"
	RFC822_HEADER_MIME_TYPE = "text/rfc822-headers"
  TNEF_MIME_TYPE = "application/ms-tnef"

  KNOWN_ATTACHMENT_CONTENT_TYPES = [/application\//, /image\//, /audio\//, /video\//, /x-url\//, /java\//].freeze

  FAILED_MAILS_EXPIRY = 604800

  DEFAULT_CHARSET = "UTF-8"

  DEFAULT_ENCODING_FORMATS = Encoding.name_list.uniq.map(&:upcase)
end


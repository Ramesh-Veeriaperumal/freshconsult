# TODO-RAILS3 no need of monkey patch for mail gem but anyways need to cross check
# # encoding: utf-8
# require 'action_mailer'
# require 'mail'

# module ActionMailer

#   module PartContainer
#     def field_with_attrs(value, attributes)
#       [value, *attributes.map { |k,v| "#{k}=#{v}" }].join("; ")
#     end
#   end

#   class Base
#     adv_attr_accessor :message_id

#     def create_mail
#       puts "::::::::::::::::::::::::::::::::create_mail::::::::::::::::::::::::::::::::::::::::::"
#       m = Mail.new

#       m.charset      = charset
#       m.subject      = quote_any_if_necessary(charset, subject)
#       m.to, m.from   = quote_any_address_if_necessary(charset, recipients, from)
#       m.bcc          = quote_address_if_necessary(bcc, charset) unless bcc.nil?
#       m.cc           = quote_address_if_necessary(cc, charset) unless cc.nil?
#       m.reply_to     = quote_address_if_necessary(reply_to, charset) unless reply_to.nil?
#       m.mime_version = mime_version unless mime_version.nil?
#       m.date         = sent_on.to_time rescue sent_on if sent_on
#       m.message_id   = message_id unless message_id.nil?

#       headers.each { |k, v| m[k] = v }

#       ctype, ctype_attrs = parse_content_type

#       if @parts.empty?
#         if content_type.match(/charset=/i)
#           m.content_type = field_with_attrs(ctype, ctype_attrs)
#         else
#           m.content_type = "#{content_type}; charset=#{charset}"
#         end
#         m.body = normalize_new_lines(body)
#       else
#         if String === body
#           part = Mail::Part.new
#           part.body = normalize_new_lines(body)
#           part.content_type = field_with_attrs(ctype, ctype_attrs)
#           part.content_disposition = "inline"
#           m.add_part part
#         end

#         @parts.each do |p|
#           # if content_disposition is inline attachment and plain or html 
#           # add the actionmailer part to Mail::Message
          
#           if ((p.content_disposition != "attachment") || (p.headers && p.headers["Content-Disposition"] =~ /inline/))
#             part = (Mail::Part === p ? p : p.to_mail(self))
#             m.add_part(part)  
#           # in case of attachments
#           else
#             attachment_data = {
#                                 :content => p.body,
#                                 :content_transfer_encoding => :binary
#                               }
#             attachment_data.merge!({:mime_type => p.content_type}) if p.content_type
#             m.attachments[p.filename] = attachment_data
#           end

#         end

#         if ctype =~ /multipart/
#           ctype_attrs.delete "charset"
#           m.content_type = field_with_attrs(ctype, ctype_attrs)
#         end
#       end

#       if m.content_type =~ /^multipart/ && !m.content_type.include?("boundary=") && m.body.boundary.present?
#         ctype_attrs["boundary"] = m.body.boundary
#         m.content_type = field_with_attrs(ctype, ctype_attrs)
#       end

#       @mail = m
#     end

#     def perform_delivery_smtp(mail)
#       puts ":::::: initializer perform_delivery_smtp"
#       destinations = mail.destinations
#       mail.ready_to_send!
#       sender = (mail['return-path'] && mail['return-path'].address) || Array(mail.from).first

#       smtp = Net::SMTP.new(smtp_settings[:address], smtp_settings[:port])
#       smtp.enable_starttls_auto if smtp_settings[:enable_starttls_auto] && smtp.respond_to?(:enable_starttls_auto)
#       smtp.start(smtp_settings[:domain], smtp_settings[:user_name], smtp_settings[:password],
#                  smtp_settings[:authentication]) do |smtp|
#         smtp.sendmail(mail.encoded, sender, destinations)
#       end
#     end
#   end

#   class Part
#     def to_mail(defaults)
#       part = Mail.new

#       ctype, ctype_attrs = parse_content_type(defaults)

#       if @parts.empty?
#         part.content_transfer_encoding = transfer_encoding || "quoted-printable"
#         case (transfer_encoding || "").downcase
#           when "base64" then
#             part.body = Mail::Encodings::Base64.encode(body)
#           when "quoted-printable"
#             part.body = [normalize_new_lines(body)].pack("M*")
#           else
#             part.body = body
#         end

#         # Always set the content_type after setting the body and or parts!
#         # Also don't set filename and name when there is none (like in
#         # non-attachment parts)
#         if content_disposition == "attachment"
#           ctype_attrs.delete "charset"
#           part.content_type = field_with_attrs(ctype,
#             squish("name" => filename).merge(ctype_attrs))
#           part.content_disposition = field_with_attrs(content_disposition,
#             squish("filename" => filename).merge(ctype_attrs))
#         else
#           part.content_type field_with_attrs(ctype, ctype_attrs)
#           part.content_disposition = content_disposition
#         end
#       else
#         if String === body
#           @parts.unshift Part.new(
#             :charset => charset,
#             :body => @body,
#             :content_type => 'text/plain'
#           )
#           @body = nil
#         end

#         @parts.each do |p|
#           prt = (Mail::Part === p ? p : p.to_mail(defaults))
#           part.add_part(prt)
#         end

#         if ctype =~ /multipart/
#           ctype_attrs.delete 'charset'
#           part.content_type = field_with_attrs(ctype, ctype_attrs)
#         end
#       end

#       if part.content_type =~ /^multipart/ && !part.content_type.include?("boundary=") && part.body.boundary.present?
#         ctype_attrs["boundary"] = part.body.boundary
#         part.content_type = field_with_attrs(ctype, ctype_attrs)
#       end

#       headers.each { |k,v| part[k] = v }

#       part
#     end
#   end

# end
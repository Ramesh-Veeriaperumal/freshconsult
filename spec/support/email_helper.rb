#include ActionController::TestProcess

module EmailHelper

	RANGE = [*'0'..'9', *'a'..'z', *'A'..'Z', *'-', *'.']

	attr_accessor :to, :from, :cc, :reply_to, :attachments, :cid

	def new_email options={}
		set_essentials(options)
		mail_main = Faker::Lorem.paragraphs(5).join(" ")
		generate_attachments(options[:attachments], options[:inline], options[:large]) if options[:attachments]
		{
			:from => from,
			:to => to,
			:cc => cc,
			:html => Nokogiri::HTML(mail_main).at_css('body').inner_html,
			:text => mail_main,
			:headers => get_header(options[:email_config], options[:m_id], options[:auto]),
			:subject => Faker::Lorem.words(10).join(" "),
			:sender_ip => random_ip,
			:envelope => get_envelope(options[:email_config], options[:another_config]),
			:dkim =>"{@gmail.com : fail (body has been altered)}",
			:attachments => options[:attachments] || 0,
			:SPF => "pass"
		}.merge(attachments || {})
	end

	def set_essentials options
		self.from = random_email
		self.to = generate_emails(rand(5), options[:email_config], options[:include_to])
		self.cc = generate_emails(rand(10), options[:include_cc])
		# self.mail_main = Faker::Lorem.paragraphs(5).join(" ")
		self.reply_to = options[:reply]
	end

	def generate_attachments number, content_id=nil, large=nil
		attach = {}
		attachment_in = {}
		number.times do |i|
			if large
				buffer = ("a" * 1024).freeze
				file = File.open("spec/fixtures/files/tmp15.doc", 'wb') { |f| 20.kilobytes.times { f.write buffer } }
				attach["attachment#{i+1}"] = fixture_file_upload("files/tmp15.doc", 'text')
				attachment_in["attachment#{i+1}"] = {:filename => "tmp15.txt", :name => "tmp15.txt", :type => 'text'}
			else
				file = fixture_file_upload('files/attachment.txt', 'text/plain')
				attach["attachment#{i+1}"] = file
				attachment_in["attachment#{i+1}"] = {:filename => "attachment.txt", :name => "attachment.txt", :type => 'text/plain'}
			end
		end
		attach = con_ids(attach) if content_id
		attachment_in = attachment_info_cid(attachment_in) if content_id
		attach["attachment-info"] = attachment_in.to_json
		self.attachments = attach
	end

	def random_ip
		"#{rand(1..255)}.#{rand(255)}.#{rand(255)}.#{rand(255)}"
	end

	def message_id
		"<#{random_string(rand(1..70))}@#{random_string(rand(1..10))}.#{random_domain}>"
	end

	def random_string n
		Array.new(n){RANGE.sample}.join
	end

	def random_domain
		["com", "co.in", "co.cc", "travel", "museum", "cc", "in", "es"].sample
	end

	def get_m_id headers
		if (headers =~ /message-id: <([^>]+)/i)
			return $1
		end
	end

	def random_name
		"#{random_string(rand(1..10))}, #{random_string(rand(10))}"
	end

	def random_email
		Faker::Internet.email
	end

	def generate_emails count, email_config = nil, other_to = nil
		email_array = []
		format = ['format_1', 'format_2', 'format_3', 'format_4'].sample
		count.times{ email_array << send(format) }
		if email_config
			email_array << "#{random_name} <#{email_config}>"
			email_array << "<#{other_to}>" if other_to
		end
		email_array.shuffle!
		email_array.join(", ")
	end

	def format_1 email = nil
		"#{random_name} <#{email || random_email}>"
	end

	def format_2 email = nil
		"<#{email || random_email}>"
	end

	def format_3 email = nil
		%("#{random_name}" <#{email || random_email}>)
	end

	def format_4 email = nil
		"#{email || random_email}"
	end

	def get_envelope email_config, another_config = nil
		a = {
			:to => [email_config],
			:from => from
		}
		a[:to] << another_config if another_config
		a.to_json
	end

	def span_gen(ticket_id)
		%(<span title="fd_tkt_identifier" style='font-size:0px; font-family:"fdtktid"; min-height:0px; height:0px; opacity:0; max-height:0px; line-height:0px; color:#ffffff'>#{ticket_id}</span>)
	end

	def style_span_gen(ticket_id)
		%(<span style='font-size:0px; font-family:"fdtktid"; min-height:0px; height:0px; opacity:0; max-height:0px; line-height:0px; color:#ffffff'>#{ticket_id}</span>)
	end

	def get_header email_config, m_id, auto
		%(Received: by mx-005.sjc1.sendgrid.net with SMTP id n7jhL6gJjE Mon, 09 Dec 2013 12:22:01 +0000 (GMT)\n
			Received: from mail-we0-f175.google.com (mail-we0-f175.google.com [74.125.82.175]) by mx-005.sjc1.sendgrid.net (Postfix) with ESMTPS id 8CA39E83644 for <#{email_config}>;
			Mon,  9 Dec 2013 12:22:00 +0000 (GMT)\n
			Received: by mail-we0-f175.google.com with SMTP id t60so3321281wes.20 for <support@green.freshbugs.com>; Mon, 09 Dec 2013 04:21:59 -0800 (PST)\n
			DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed; d=gmail.com; s=20120113;
			h=mime-version:reply-to:date:message-id:subject:from:to:cc:references:in-reply-to :content-type; bh=S5DmbRJfiZcABAr0IOIjy8i9u+fz1id1uiwiVexrrfA=;
			b=EoCyUNebROXHJzprUFu1tex220+zQIX/psMO8/kCjAAROvKtuwr9Cw/EyyqvrGLaJl OVaBUPN8r4/payU4idpSYc4UrnIQnyFYMhsQf5yO/iZw0xybA+FrXhvlKO1589OsVe2p pxz9iKF91anM1c+oUgf5+hn+PNQB7AyWM22hUiWG6Ot7DTth2/ekr9tGp2yfLnJsW2a1
			GL6jYMSMjm5MLDD/QXRFWMA9AJZUrNkSZtzs06pAnHwb7Xg/sQjn+EoRiiKGT93USN/j PQRXrF0g2bb447HbJcvO6Gqllr+EeeQKIsn4M+Dnqvqzwi5YTKbh57fcSI+JW9nC+jvr RVtA==\nMIME-Version: 1.0\nX-Received: by 10.180.20.15 with SMTP id
			j15mr13980557wie.4.1386591719017; Mon, 09 Dec 2013 04:21:59 -0800 (PST)\nReceived: by 10.217.54.199 with HTTP; Mon, 9 Dec 2013 04:21:58 -0800 (PST)\nReply-To: #{reply_to || random_email}\nDate: #{DateTime.now}\nMessage-ID: #{message_id}\n
			Subject: New parameter fetch - Lesser\nFrom: #{format_1(from)}\nTo: #{to}\nCc: #{cc}\nReferences: #{generate_references(m_id)}\nIn-Reply-To: <#{m_id || ""}>\nPrecedence: #{auto ? "auto_reply" : ""}\nContent-Type: multipart/mixed; boundary=bcaec53f3985dc812004ed190a39\n)
	end

	def generate_references m_id
		ref = Array.new(rand(1..4)){message_id}.join(", ")
		ref = ref+", <#{m_id}>" if m_id
	end

	def add_forward_content
		%(>From: #{format_3}\n)
	end

	def charset_hash(different=nil)
		{
			:to => "utf8",
			:cc => "utf8",
			:html => different ? "unicode" : "ISO-8859-1",
			:subject => different ? "ks_c_5601-1987" : "utf8",
			:text => "ISO-8859-1"
		}.to_json
	end

	def con_ids attach
		self.cid = random_string(20)
		attach["content-ids"] = {cid => "attachment1"}.to_json
		attach
	end

	def attachment_info_cid attachment_in
		attachment_in["attachment1"].merge!({"content_id" => cid})
	end

	def content_id
		cid
	end

	def new_ebay_email options={}
		from = "bmkbab_eyw5248uaz@members.ebay.in"
		ebay_subject = "Shipping: bmkbabsat sent a message about Baby dress #221707006208"
		to = generate_emails(rand(5), options[:email_config], options[:include_to])
		self.reply_to = options[:reply]
		mail_main = Faker::Lorem.paragraphs(5).join(" ")
		generate_attachments(options[:attachments], options[:inline], options[:large]) if options[:attachments]
		{
			:from => from,
			:to => to,
			:cc => cc,
			:html => Nokogiri::HTML(mail_main).at_css('body').inner_html,
			:text => mail_main,
			:headers => get_header(options[:email_config], options[:m_id], options[:auto]),
			:subject => ebay_subject,
			:sender_ip => random_ip,
			:envelope => get_envelope(options[:email_config], options[:another_config]),
			:dkim =>"{@gmail.com : fail (body has been altered)}",
			:attachments => options[:attachments] || 0,
			:SPF => "pass"
		}.merge(attachments || {})
	end

end

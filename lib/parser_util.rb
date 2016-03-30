# encoding: utf-8
module ParserUtil

  require 'mail'

  include AccountConstants
  include EmailParser

  def parse_email(email)
    if email =~ /(.+) <(.+?)>/
      name = $1
      email = $2
    elsif email =~ /<(.+?)>/
      email = $1
    else email =~ EMAIL_REGEX
      email = $1
    end

    { :email => email, :name => name }
  end 

  def parse_email_with_mail_parser(email)
    mail_parser(email)
  rescue Exception => e
    Rails.logger.debug "Exception when validating email list : #{email} : #{e.message} : #{e.backtrace}"
    parse_email_without_mail_parser(email)
  end 

  def get_emails emails
    email_array = emails.split(",") if emails
    parsed_email_array = []
    (email_array || []).each_with_index do |email, index|
      parsed_email = parse_email_text(email)
      if (parsed_email[:email] =~ EMAIL_REGEX)
        parsed_email_array << parsed_email
      else
        email_array[index+1] = "#{email} #{email_array[index+1]}" if email_array[index+1]
      end
    end
    parsed_email_array.uniq
  end

  def get_email_array emails
    plain_emails = []
    get_emails(emails).each do |e|
      plain_emails << e[:email].downcase.strip
    end
    plain_emails
  end

  def get_email_array_with_mail_parser emails
    parse_addresses(emails)[:plain_emails]
  rescue Exception => e
    Rails.logger.debug "Exception when validating email list : #{emails} : #{e.message} : #{e.backtrace}"
    get_email_array_without_mail_parser(emails)
  end


	def parse_email_text(email_text)
		if email_text =~ /"?(.+?)"?\s+<(.+?)>/
    	{:name => $1.tr('"',''), :email => $2}
  	elsif email_text =~ /<(.+?)>/
   		{:name => "", :email => $1}
   	else
   		{:name => "", :email => email_text}	
  	end
	end

  def parse_email_text_with_mail_parser(email)
    mail_parser(email)
  rescue Exception => e
    Rails.logger.debug "Exception when validating email list : #{email} : #{e.message} : #{e.backtrace}"
    parse_email_text_without_mail_parser(email)
  end 

  def parse_email_with_domain(email_text)
    parsed_email = parse_email_text(email_text)   
    name = parsed_email[:name] || ""
    email = parsed_email[:email]
    if((email && !(email =~ EMAIL_REGEX) && (email_text =~ EMAIL_REGEX)) || (email_text =~ EMAIL_REGEX))
      email = $1 
    end
    domain = (/@(.+)/).match(email).to_a[1]
    {:name => name, :email => email, :domain => domain}
  end
  
  def parse_email_with_domain_with_mail_parser(email)
    mail_parser(email)
  rescue Exception => e
    Rails.logger.debug "Exception when validating email list : #{email} : #{e.message} : #{e.backtrace}"
    parse_email_with_domain_without_mail_parser(email)
  end 

  def parse_to_comma_sep_emails(emails)
    emails.map { |email| parse_email_text(email)[:email] }.join(", ") 
  end

  def fetch_valid_emails(addresses, options = {})
    if addresses.is_a? String
      addresses = addresses.split(/,|;/)
    end

    return [] if addresses.blank?

    ignore_emails = options[:ignore_emails].to_a

    addresses = addresses.collect do |address|
      next if address.blank?
 
      address = address.gsub('"','')

      matches = address.strip.scan(/(\w[^<\>]*)<(\b[A-Z0-9.'_&%+-]+@[A-Z0-9.-]+\.[A-Z]{2,15}\b)\>\z|\A<!--?((\b[A-Z0-9.'_&%+-]+)@[A-Z0-9.-]+\.[A-Z]{2,15}\b)-->?\z/i)
      
      if matches[0] && matches[0][1]
        email = matches[0][1]
        name = matches[0][0]
      elsif matches[0] && matches[0][2]
        email = matches[0][2]
        name = matches [0][3]
      else
        # Validating plain email addresses,
        simple_email_regex = /\b[-a-zA-Z0-9.'’&_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b/
        simple_email  = address.scan(simple_email_regex)
        if simple_email
          email = simple_email[0]
          name = ""
        end
      end

      if email.present?
        email = email.downcase.strip
        next if ignore_emails.include?(email)

        if name.present?
          "#{name.gsub(/\./, ' ').strip} <#{email}>".strip
        else
          email
        end
      end
    end
    addresses.compact.uniq
  end

  def fetch_valid_emails_with_mail_parser(addresses, options = {})
    parse_addresses(addresses, options)[:emails]
  rescue Exception => e
    Rails.logger.debug "Exception when validating email list : #{addresses} : #{e.message} : #{e.backtrace}"
    fetch_valid_emails_without_mail_parser(addresses, options)
  end
  
  # possibly dead code validate_emails, extract_email, valid_email?
  def validate_emails(email_array, ticket = @parent)
    unless email_array.blank?
      if email_array.is_a? String
        email_array = email_array.split(/,|;/)
      end
        email_array.delete_if {|x| (extract_email(x) == ticket.requester.email or !(valid_email?(x))) }
        email_array = email_array.collect{|e| e.gsub(/\,/,"")}
        email_array = email_array.uniq
    end
  end
    
  def extract_email(email)
    email = $1 if email =~ /<(.+?)>/
    email
  end
    
  def valid_email?(email)
    email = extract_email(email)
    (email =~ EMAIL_SCANNER) ? true : false
  end

  # removes trailing characters after + 
  # email = redhat+01@freshdesk.com
  # returns redhat@freshdesk.com
  def trim_trailing_characters(email)
    email.sub(/\+.*@/,"@")
  end

  def format_name(name)
    name =~ SPECIAL_CHARACTERS_REGEX ? name = "\"#{name.gsub(/\./, ' ').strip}\"" : name
  end

  def mail_parser(email)
    parsed_hash = { :email => email, :name => nil, :domain => nil }
    parsed_email = Mail::ToField.new 
    parsed_email.value = email
    name_prefix = ""
    parsed_email.addrs.each_with_index do |email,index|
      address = email.address
      address = Mail::Encodings.unquote_and_convert_to(address, "UTF-8") if address.include?("=?")
      position = address =~ EMAIL_REGEX
      if position
        parsed_hash[:email] = $1.downcase
        if email.domain.present?
          parsed_hash[:name] = email.name.prepend(name_prefix) if email.name.present?
          parsed_hash[:domain] = email.domain
        else
          name = name_prefix << address[0..position-1]
          name.gsub!("<", "")
          name.gsub!(">", "")
          parsed_hash[:name] = format_name(name)
          parsed_hash[:domain] = parsed_hash[:email].split("@")[1]
        end
        break
      else
        name_prefix << address.to_s << ','
      end
    end
    parsed_hash
  end
  
  alias_method_chain :parse_email, :mail_parser
  alias_method_chain :parse_email_text, :mail_parser
  alias_method_chain :parse_email_with_domain, :mail_parser
  alias_method_chain :get_email_array, :mail_parser
  alias_method_chain :fetch_valid_emails, :mail_parser

end

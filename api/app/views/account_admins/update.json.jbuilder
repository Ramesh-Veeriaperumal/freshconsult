if @item.contact_info.present?
  @item.contact_info.each_pair do |key, value|
    json.set! key, value
  end
end

if @item.company_info.present? && @item.company_info[:name]
  json.set! :company_name, @item.company_info[:name]
end

if @item.invoice_emails.present?
  json.set! :invoice_emails, @item.invoice_emails
end 
class Billing::WebhookParser

  attr_accessor :content

  def initialize(invoice)
    @content = invoice
  end

  def invoice_hash
    {
      :customer_name         => invoice_customer_name,
      :chargebee_invoice_id  => invoice_id,
      :amount                => invoice_amount,
      :sub_total             => invoice_sub_total,
      :currency              => invoice_currency,
      :details               => invoice_details,
      :generated_on          => invoice_generated_date
    }
  end

  private

  def invoice_id
    content["invoice"]["id"]
  end

  def invoice_customer_name
    "#{content['invoice']['billing_address']['first_name']} #{content['invoice']['billing_address']['last_name']}"
  end

  def invoice_amount
    content["invoice"]["amount"].to_f / 100
  end

  def invoice_sub_total
    content['invoice']['sub_total'].to_f / 100
  end

  def invoice_currency
    content['transaction']['currency_code']
  end

  def invoice_generated_date
    Time.at(content['transaction']['linked_invoices'].first['invoice_date'])
  end

  def invoice_transactions
    content[:invoice][:linked_transactions].map do |transaction_hash|
      {
        :transaction_date => Time.at(transaction_hash[:applied_at]).utc,
        :transaction_type => transaction_hash[:txn_type],
        :transaction_status => transaction_hash[:txn_status],
        :transaction_amount => transaction_hash[:txn_amount].to_f / 100
      }
    end
  end

  def invoice_line_items
    content[:invoice][:line_items].map do |item|
      {
        :unit_price   => item[:unit_amount].to_f/100, 
        :quantity     => item[:quantity],
        :amount       => item[:amount].to_f/100, 
        :description  => item[:description]
      }
    end
  end

  def invoice_details
    {
      :line_items => invoice_line_items,
      :transaction_details =>invoice_transactions
    }
  end
end

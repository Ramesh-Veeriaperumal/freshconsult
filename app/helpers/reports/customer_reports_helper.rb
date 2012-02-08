module Reports::CustomerReportsHelper
  
  def get_sla_image(sla_diff)
    if sla_diff.nil?
      return "neutral"
    end
    if sla_diff > 0
      return "positive"
    elsif sla_diff < 0
      return "negative"
    else
      return "neutral"
    end
  end
  
  def fetch_customer_name(customer)
   if customer
    customer.name
  else
    "Customer"
   end
  end
  
end
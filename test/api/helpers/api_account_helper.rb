module ApiAccountHelper
  def create_subscription_payment(args)
    subscription_payment  = FactoryGirl.build(:subscription_payment,
      account_id: Account.current.id,
      subscription_id: 1,
      amount: args[:amount] || 10
    )
    subscription_payment.save
    subscription_payment
  end
  
  def chargebee_subscripiton_reponse
    {
      "subscription": {
          "id": "1",
          "plan_id": "garden_jan_17_annual",
          "plan_quantity": 10,
          "status": "cancelled",
          "trial_start": 1537521718,
          "trial_end": 1537521916,
          "current_term_start": 1537685051,
          "current_term_end": 1538389526,
          "created_at": 1368442623,
          "started_at": 1368442623,
          "activated_at": 1537521916,
          "cancelled_at": 1538389526,
          "has_scheduled_changes": false,
          "object": "subscription",
          "due_invoices_count": 0
      },
      "customer": {
          "id": "1",
          "first_name": "Support",
          "last_name": "Support",
          "email": "test@test.com",
          "company": "Test Account",
          "auto_collection": "on",
          "allow_direct_debit": false,
          "created_at": 1368442623,
          "taxability": "taxable",
          "object": "customer",
          "billing_address": {
              "first_name": "Name",
              "last_name": "Last Name",
              "line1": "40,MGR Main road kodandarama nagar,Perungudi,chennai,Tamilnadu-600096",
              "city": "chennai",
              "state_code": "TN",
              "state": "Tamil Nadu",
              "country": "IN",
              "zip": "600096",
              "object": "billing_address"
          },
          "card_status": "valid",
          "payment_method": {
              "object": "payment_method",
              "type": "card",
              "reference_id": "tok_HngTofnR4GzFGPJez",
              "gateway": "chargebee",
              "status": "valid"
          },
          "account_credits": 0,
          "refundable_credits": 9637800,
          "excess_payments": 0,
          "meta_data": {"customer_key": "minus.freshpo.com"}
      },
      "card": {
          "status": "valid",
          "gateway": "chargebee",
          "first_name": "First Name",
        
      }
    }
  end
end

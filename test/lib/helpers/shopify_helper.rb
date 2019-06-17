module ShopifyHelper
  def orders
    {
      orders: [
        {
          id: 1234,
          email: 'test@gmail.com',
          closed_at: '',
          created_at: '2019-06-03T09:31:55-04:00',
          updated_at: '2019-06-03T09:31:56-04:00',
          number: 19,
          note: '',
          token: '01b14f8ddedf10892741b0ba7065f044',
          gateway: 'manual',
          test: false,
          total_price: '1500.00',
          subtotal_price: '1500.00',
          total_weight: 0,
          total_tax: '0.00',
          taxes_included: false,
          currency: 'INR',
          financial_status: 'paid',
          confirmed: true,
          total_discounts: '0.00',
          total_line_items_price: '1500.00',
          cart_token: '',
          buyer_accepts_marketing: false,
          name: '###FF##1019',
          referring_site: '',
          landing_site: '',
          cancelled_at: '',
          cancel_reason: '',
          total_price_usd: '21.56',
          checkout_token: '',
          reference: '',
          user_id: 265,
          location_id: '',
          source_identifier: '',
          source_url: '',
          processed_at: '2019-06-03T09:31:55-04:00',
          device_id: '',
          phone: '',
          customer_locale: '',
          app_id: 745,
          browser_ip: '',
          landing_site_ref: '',
          order_number: 1019,
          discount_applications: [],
          discount_codes: [],
          note_attributes: [],
          payment_gateway_names: [
            'manual'
          ],
          processing_method: 'manual',
          checkout_id: '',
          source_name: 'shopify_draft_order',
          fulfillment_status: '',
          tax_lines: [],
          tags: '',
          contact_email: 'test@gmail.com',
          order_status_url: 'https://test.myshopify.com/1234/orders/6474/authenticate?key=xyz',
          presentment_currency: 'INR',
          total_line_items_price_set: {
            shop_money: {
              amount: '1500.00',
              currency_code: 'INR'
            },
            presentment_money: {
              amount: '1500.00',
              currency_code: 'INR'
            }
          },
          total_discounts_set: {
            shop_money: {
              amount: '0.00',
              currency_code: 'INR'
            },
            presentment_money: {
              amount: '0.00',
              currency_code: 'INR'
            }
          },
          total_shipping_price_set: {
            shop_money: {
              amount: '0.00',
              currency_code: 'INR'
            },
            presentment_money: {
              amount: '0.00',
              currency_code: 'INR'
            }
          },
          subtotal_price_set: {
            shop_money: {
              amount: '1500.00',
              currency_code: 'INR'
            },
            presentment_money: {
              amount: '1500.00',
              currency_code: 'INR'
            }
          },
          total_price_set: {
            shop_money: {
              amount: '1500.00',
              currency_code: 'INR'
            },
            presentment_money: {
              amount: '1500.00',
              currency_code: 'INR'
            }
          },
          total_tax_set: {
            shop_money: {
              amount: '0.00',
              currency_code: 'INR'
            },
            presentment_money: {
              amount: '0.00',
              currency_code: 'INR'
            }
          },
          total_tip_received: '0.0',
          admin_graphql_api_id: 'gid://shopify/Order/154',
          line_items: [
            {
              id: 1234,
              variant_id: 1334,
              title: 'Jeans',
              quantity: 1,
              sku: '',
              variant_title: '',
              vendor: 'Testdemo2',
              fulfillment_service: 'manual',
              product_id: 245,
              requires_shipping: true,
              taxable: true,
              gift_card: false,
              name: 'Jeans',
              variant_inventory_management: '',
              properties: [],
              product_exists: true,
              fulfillable_quantity: 1,
              grams: 0,
              price: '1000.00',
              total_discount: '0.00',
              fulfillment_status: '',
              price_set: {
                shop_money: {
                  amount: '1000.00',
                  currency_code: 'INR'
                },
                presentment_money: {
                  amount: '1000.00',
                  currency_code: 'INR'
                }
              },
              total_discount_set: {
                shop_money: {
                  amount: '0.00',
                  currency_code: 'INR'
                },
                presentment_money: {
                  amount: '0.00',
                  currency_code: 'INR'
                }
              },
              discount_allocations: [],
              admin_graphql_api_id: 'gid://shopify/LineItem/245',
              tax_lines: []
            },
            {
              id: 245,
              variant_id: 134,
              title: 'T-shirt',
              quantity: 1,
              sku: '',
              variant_title: '',
              vendor: 'Testdemo2',
              fulfillment_service: 'manual',
              product_id: 241,
              requires_shipping: true,
              taxable: true,
              gift_card: false,
              name: 'T-shirt',
              variant_inventory_management: '',
              properties: [],
              product_exists: true,
              fulfillable_quantity: 1,
              grams: 0,
              price: '500.00',
              total_discount: '0.00',
              fulfillment_status: '',
              price_set: {
                shop_money: {
                  amount: '500.00',
                  currency_code: 'INR'
                },
                presentment_money: {
                  amount: '500.00',
                  currency_code: 'INR'
                }
              },
              total_discount_set: {
                shop_money: {
                  amount: '0.00',
                  currency_code: 'INR'
                },
                presentment_money: {
                  amount: '0.00',
                  currency_code: 'INR'
                }
              },
              discount_allocations: [],
              admin_graphql_api_id: 'gid://shopify/LineItem/2495445467249',
              tax_lines: []
            }
          ],
          shipping_lines: [],
          billing_address: {
            first_name: 'Test ',
            address1: '',
            phone: '',
            city: '',
            zip: '',
            province: 'Andaman and Nicobar',
            country: 'India',
            last_name: 'Demo',
            address2: '',
            company: '',
            latitude: '',
            longitude: '',
            name: 'Test  Demo',
            country_code: 'IN',
            province_code: 'AN'
          },
          shipping_address: {
            first_name: 'Test ',
            address1: '',
            phone: '',
            city: '',
            zip: '',
            province: 'Andaman and Nicobar',
            country: 'India',
            last_name: 'Demo',
            address2: '',
            company: '',
            latitude: '',
            longitude: '',
            name: 'Test  Demo',
            country_code: 'IN',
            province_code: 'AN'
          },
          fulfillments: [],
          refunds: [],
          customer: {
            id: 685,
            email: 'test@gmail.com',
            accepts_marketing: false,
            created_at: '2018-08-09T04:07:10-04:00',
            updated_at: '2019-06-03T09:31:55-04:00',
            first_name: 'Test',
            last_name: 'Demo',
            orders_count: 12,
            state: 'disabled',
            total_spent: '9500.00',
            last_order_id: 154,
            note: '',
            verified_email: true,
            multipass_identifier: '',
            tax_exempt: false,
            phone: '',
            tags: 'password page, prospect',
            last_order_name: '###FF##1019',
            currency: 'INR',
            accepts_marketing_updated_at: '2019-01-03T22:36:22-05:00',
            marketing_opt_in_level: '',
            admin_graphql_api_id: 'gid://shopify/Customer/685',
            default_address: {
              id: 876,
              customer_id: 685,
              first_name: 'Test ',
              last_name: 'Demo',
              company: '',
              address1: '',
              address2: '',
              city: '',
              province: 'Andaman and Nicobar',
              country: 'India',
              zip: '',
              phone: '',
              name: 'Test  Demo',
              province_code: 'AN',
              country_code: 'IN',
              country_name: 'India',
              default: true
            }
          }
        }
      ]
    }
  end
end

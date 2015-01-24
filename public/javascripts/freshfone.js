(function ($) {
    "use strict";
    
    var search_freshfone,$buy_numbers_form,
        current_toll_free_country = "US",
        current_toll_free_prefix = "",
        activeTab,
        numeric_search_results,
        toll_free_search_results,
        $buyNumberContainer = $('.twilio-buy-numbers'),
        $localSearchResults = $('#local_search_results'),
        $localSearchResultsContainer = $localSearchResults.parent(),
        $tollfreeSearchResults = $('#toll_free_search_results'),
        $tollfreeSearchResultsContainer = $tollfreeSearchResults.parent(),
        $supportedCountries = $("#supported_countries"),
        $stateList = $buyNumberContainer.find('.search-bar-state'),
        $tollFreeSearchInput = $buyNumberContainer.find('#toll-free #search_input'),
        $localSearchInput = $buyNumberContainer.find('#local #search_input'),
        default_numeric_options = {
            'mode': 'numeric'
        },
        default_toll_free_options = {
            'mode': 'toll_free'
        };


    function populate_request_body(options) {
        if (options.mode === "numeric") {
            var region = "";
            if ($supportedCountries.val() === "US") {
                region = options.region || $("#supported_cities").val();
            }
            return {
                "type": "local",
                "in_region": region,
                "contains": $localSearchInput.val()
            };
        } else if (options.mode === "toll_free") {
            return {
                "type": "toll_free",
                "area_code": current_toll_free_prefix,
                "contains": $tollFreeSearchInput.val()
            };
        }
    }

    function search_local_numbers(options) {
        $localSearchResultsContainer.addClass('sloading loading-small default-results-view');
        $localSearchResults.hide();
        options = options || default_numeric_options;
        var search_options = populate_request_body(options);

        if (search_freshfone) {
            search_freshfone.abort();
        }
        search_freshfone = $.ajax({
            url: '/admin/freshfone/available_numbers',
            data: {
                "search_options": search_options,
                "country": $supportedCountries.val()
            },
            success: function (data) {
                numeric_search_results = data;
                $localSearchResultsContainer.removeClass('sloading loading-small default-results-view');
                $localSearchResults.show();
                $localSearchResults.html(data);
            }
        });
    }

    function search_toll_free_numbers(options) {
        $tollfreeSearchResultsContainer.addClass('sloading loading-small default-results-view');
        $tollfreeSearchResults.hide();
        options = options || default_toll_free_options;
        var search_options = populate_request_body(options);

        if (search_freshfone) {
            search_freshfone.abort();
        }
        search_freshfone = $.ajax({
            url: '/admin/freshfone/available_numbers',
            data: {
                "search_options": search_options,
                "country": $('#toll_free_supported_countries').val()
            },
            success: function (data) {
                toll_free_search_results = data;
                $tollfreeSearchResultsContainer.removeClass('sloading loading-small default-results-view');
                $tollfreeSearchResults.show();
                $tollfreeSearchResults.html(data);
            }
        });
    }


    if ($supportedCountries.val() === "US") {
        $stateList.show();
        search_local_numbers();
    }

    $buyNumberContainer.on('click', '#toll-free-tab', function () {
        if (toll_free_search_results) {
            $tollfreeSearchResults.html(toll_free_search_results);
        } else {
            search_toll_free_numbers();
        }
    });

    $buyNumberContainer.on('click', '#local-tab', function () {
        if (numeric_search_results) {
            $localSearchResults.html(numeric_search_results);
        } else {
            search_local_numbers();
        }
    });

    $buyNumberContainer.on('change', '#toll_free_supported_countries', function () {
        current_toll_free_country = $(this).val();
        current_toll_free_prefix = "";
        $('.toll-free-prefixes').html($('.toll_free_' + current_toll_free_country).clone());
        $('.toll-free-prefixes .toll_free_prefix_' + current_toll_free_country).addClass('select2');
        search_toll_free_numbers();
    });

    $buyNumberContainer.on('change', '#toll_free_prefix_search', function () {
        var prefix = $(this).val();
        current_toll_free_prefix = (prefix === "Any") ? "" : prefix;
        search_toll_free_numbers();
    });

    $buyNumberContainer.on('change', '#supported_countries', function () {
        var country = $(this).val();
        if (country === "US") {
            $stateList.show();
        } else {
            $stateList.hide();
        }
        search_local_numbers();
    });

    $buyNumberContainer.on('change', '#supported_cities', function () {
        var city = $(this).val();
        search_local_numbers({
            'mode': 'numeric',
            'region': city
        });
    });

    $localSearchInput.on('keydown', function (ev) {
        if (ev.keyCode === 13) {
            search_local_numbers();
        }
    });

    $tollFreeSearchInput.on('keydown', function (ev) {
        if (ev.keyCode === 13) {
            search_toll_free_numbers();
        }
    });


    $('body').on('click.buy_numbers.freshfone', '.purchase_number', function(ev){
        ev.preventDefault();
        var $this = $(this);
        var country = $('#supported_countries option:selected').text();
        var country_code = $('.buy_available_number #country').val();
        $('#open-purchase-confirmation').trigger('click');
        $('#purchase-confirmation .loading-box').toggle(false);
        var address_required = ($this.data('addressRequired') && !isAddressAlreadyExisit(country_code));

        $('#purchase-confirmation .modal-title').text($this.attr('title'));
        $('#purchase-confirmation .number-rate').text($this.data('rate'));

        $('#purchase-confirmation .address-required-alert').toggle(address_required);

        // Unbind Purchase button (freshdialog)
        $('#purchase-confirmation').off('click.submit.modal');

        // Unbind Purchase button (buy_freshfone_numbers)
        $('#purchase-confirmation').off('click.buy_numbers.freshfone');

        // New Bind for Purchase button to submit the current link's form
        $('#purchase-confirmation').on('click.buy_numbers.freshfone', '[data-submit="modal"]', function(ev) {
            ev.preventDefault();
            $(this).button("loading");
            $buy_numbers_form = $this.parents('form');
            if($this.data('addressRequired')){
              $('#freshfone_address_form').submit();
            } else {
              $this.parents('form').submit();  
            }
        });
        resetErrorMessages();
        
        if(address_required){
             $('#purchase-confirmation .certification-country').html(country);
             $(".freshfone-address-form #country").val(country_code);
             $(".freshfone-address-form #country_name").val(country);
             $("#freshfone_address_form input:text:visible:first").focus();
         }

    });

    $('#freshfone_address_form').submit( function() {
        var valuesToSubmit = $(this).serialize();
        $(".ajaxerrorExplanation").toggle(false);
        $.ajax({
            type: "POST",
            url: $(this).attr('action'),
            data: valuesToSubmit,
            dataType: "JSON",
            success: function(data){
                if(data.success) {
                    $('.purchaseErrorExplanation').toggle(false);
                    $buy_numbers_form.submit();  
                } else {
                    resetErrorMessages();
                    $('.purchaseErrorExplanation').toggle(true);
                    populateErrorMessage(data.errors);
                    resetPurchaseButton();
                }
            },
            error: function(data){
                resetErrorMessages();
                $(".ajaxerrorExplanation").toggle(true);
                resetPurchaseButton();
            }
        });
        return false;
    });
    function populateErrorMessage(formErrors) {
      $.map(formErrors, function(error){
          return $("<label class='error'>"+error+"</label>")
                  .appendTo($('.purchaseErrorExplanation'));
      });
    }
    function resetPurchaseButton() {
      $('#purchase-confirmation').on('click.submit.modal');
      $('#purchase-confirmation [data-submit="modal"]').button('reset');
      $('#purchase-confirmation').on('click.buy_numbers.freshfone');   
    }
    function resetErrorMessages(){
        $('.purchaseErrorExplanation').empty();
        $('.purchaseErrorExplanation').toggle(false);
        $('.ajaxerrorExplanation').toggle(false);
    }
    function isAddressAlreadyExisit(country_code) {
        var alreadyExist = false;
        toggleLoder(true);
        $.ajax({
          url: '/freshfone/address/inspect',
          dataType: "json",
          data: {"country" : country_code},
          success: function (data) {
            alreadyExist =  data.isExist;
            toggleLoder(false);
          },
          error: function (data) {
            toggleLoder(false);
          }
        });
        return alreadyExist;
    }
    function toggleLoder(toggle){
      $('#purchase-confirmation .loading-box').toggle(toggle);
      $('#purchase-confirmation .number-message').toggle(!toggle);
    }

}(jQuery));
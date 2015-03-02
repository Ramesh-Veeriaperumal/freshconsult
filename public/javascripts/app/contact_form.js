
window.App = window.App || {};
window.App.Contacts.Contact_form = window.App.Contacts.Contact_form || {};

(function ($) {
  "use strict";

  window.App.Contacts.Contact_form = {
    onFirstVisit: function (data) {
      this.onVisit(data);
    },
    onVisit: function (data) {
      this.bindAutocomplete();
      this.bindCompanySelect2();
      this.bindHandlers();
      this.bindSubmitValidation();
      this.triggerFocus();
    },

    bindAutocomplete: function () {
      $("#user_company_name").autocomplete({
        source: function (request, response) {
            $.ajax({
                url: "/search/autocomplete/companies",
                data: {
                    q: request.term
                },
                success: function (data) {
                    response($.map(data.results,
                    function(item) {
                        return {
                            label: escapeHtml(item.value),
                            value: item.value
                        }
                    }));
                }
            });
        },
          select: function (event, ui) {
                $("#user_address").focus();
              },
          open: function () {
              $(this).removeClass('ui-corner-all');
          }
        }).data("autocomplete")._renderItem = function (ul, item) {
            return $("<li></li>")
            .data("item.autocomplete", item)
            .append("<a>" + item.label + "</a>")
            .appendTo(ul);
          };
    },

    bindCompanySelect2: function () {
      $("input[name='user[tag_names]']").select2({
        tags: window.App.Contacts.Contact_form.tags_options.split(","),
        tokenSeparators: [',']
      });
    },

    bindHandlers: function () {
      this.bindContactSubmitClick();
      this.bindCustomerKeyup();
      this.bindMenuItemClick();
      this.bindAddNewMailClick();
      this.bindPrimaryMakerClick();
      this.bindRemoveImageClick();
      this.bindCancelEmailClick();
      this.toggleAddNewEmail();
      this.bindErrorFieldChanges();
      this.bindWrongEmailClick();
      this.enableClientManager();
    },

    bindContactSubmitClick: function () {
      $('body').on('click.contact_form', '#contact_submit', function(ev){
        if($.trim($('#user_company_name').val()) == '')
        {
          $('#user_client_manager').removeAttr('checked');
        }
      });
    },

    bindCustomerKeyup: function () {
      $("body").on('keyup.contact_form', '#user_company_name', function(ev) {
        var company = this.value.trim();
        if (company != "")
        {
            $('#user_client_manager').removeAttr("disabled");
        }
        else
        {
          $('#user_client_manager').removeAttr('checked');
          $('#user_client_manager').prop("disabled", true);
        }
      });
    },

    bindMenuItemClick: function () {
      $('body').on('click.contact_form', ".ui-menu-item", function(ev){
        $("#user_address").focus();
      });
    },

    bindAddNewMailClick: function () {
      $('body').on('click.contact_form', '#add_new_mail', function(ev){
        ev.preventDefault();
        if(!$(this).hasClass('disabled'))
        {
          if((!$('#emails_con .error').is(':visible') && $('#emails_con').find('input[type="text"]').last().val()) || $('#emails_con input').length == 0)
          {
            this.email=$('#emails_con input[type=text]').length;
            this.att_name="user[user_emails_attributes]["+this.email+"]";
            var field = ['<li class="new_email"><span class="remove_pad ue_cancel_email ue_action_icons ficon-minus fsize-12"></span>',
                          '<input class="email cont text ue_input" placeholder = "Enter an email" autocomplete="off" id="email_sec_new'+this.email+'" name="'+this.att_name+'[email]" ',
                          'size="30" type="text">',
                          '<input name="'+this.att_name+'[primary_role]" class="ue_primary" type="hidden" value="0">',
                          '<label id="email_sec_new'+this.email+'" class="error" for="email_sec_new'+this.email+'"></label>',
                         '</li>'].join('');
            $('ul.user_emails').append(field);
            $('#emails_con').find('input[type="text"]').last().focus();
          }
          $(this).addClass('disabled');
        }
      });
    },

    bindPrimaryMakerClick: function () {
      $('body').on('click.contact_form', '.email-tick.make_primary', function(){
        $('.email-tick').removeClass('ficon-checkmark-round primary').addClass('make_primary');
        $('ul.user_emails li').removeClass('disabled');
        var current_primary = $('input[type=text].ue_input.disabled')
        if(current_primary.data('verified') == 0)
        {
          current_primary.next().removeClass('make_primary').addClass('ficon-unverified unverified').prop('title', window.App.Contacts.Contact_form.unverified_text);
        }
        else{
          current_primary.next().prop('title', window.App.Contacts.Contact_form.mark_text);
        }
        current_primary.removeClass('disabled default_email').prop('disabled', false);
        $('.ue_remove_image').removeClass('disabled')
        $('.ue_primary').val(0);
        $(this).removeClass('make_primary').addClass('ficon-checkmark-round primary').prop('title', window.App.Contacts.Contact_form.primary_text);
        $(this).prev().addClass('disabled default_email').prop('disabled', true);
        $(this).prev().prev().addClass('disabled');
        $(this).next('.ue_primary').val(1);
        $(this).parent().addClass('disabled');
      });
    },

    bindRemoveImageClick: function () {
      $('body').on('click.contact_form', '.ue_remove_image', function(){
        if(confirm(window.App.Contacts.Contact_form.confirm_text))
        {
          $(this).parent().children("input[type=hidden].ue_destroy").val(1);
          $(this).parent().hide();
          if($('#emails_con').find('input[type=text]:visible').length==0)
          {
            $('#add_new_mail').trigger('click');
          }
        }
        $('.email').trigger('keyup');
      });
    },

    bindCancelEmailClick: function () {
      $("body").on('click.contact_form', '.ue_cancel_email', function(ev){
        ev.preventDefault();
        $(this).parent().remove();
        if(!$('ue_cancel_email').length)
          $('#add_new_mail').removeClass('disabled')

        if($('#emails_con').find('input.email:visible').length==0)
        {
          $('#add_new_mail').trigger('click');
        }
        $('.email').trigger('keyup');
      });
    },

    toggleAddNewEmail: function () {
      $('body').on('keyup.contact_form focusout.contact_form', '.email', function(){
        if($('#emails_con').find('input[type="text"]').last().val() && !$('#emails_con .error').is(':visible') && ($('#emails_con').find('input[type=text]:visible').length<5)){
          $('#add_new_mail').removeClass('disabled')
        }else{
          $('#add_new_mail').addClass('disabled')
        }

        if($('#emails_con').find('input[type=text]:visible').length >= 5){
          $('div.ue_add_email').hide();
        }else{
          $('div.ue_add_email').show();
        }
      }); 
    },

    bindErrorFieldChanges: function () {
      $('.remove_pad').each(function(rm, rv){
        if($(rv).parent().next().hasClass('fieldWithErrors'))
        {
          $(rv).attr({id:'wrong_email', title:'Click to remove this email'});
          $(rv).parent().attr('onclick', '');
        }
      });
    },

    bindWrongEmailClick: function () {
      $('body').on('click.contact_form', '#wrong_email', function () {
        $(this).parent().next().remove();
        $(this).parent().remove();
      });
    },

    bindSubmitValidation: function () {
      $('.form_for_contact').on('submit', function (ev) {
        ev.preventDefault();
        var result = true
        var email = $('#emails_con').find('input[type="text"]:visible').val(),
        twitter = $("#user_twitter_id").val().length,
        phone = $('#user_phone').val().length,
        mobile = $('#user_mobile').val().length;

        if(!email && !twitter && !phone && !mobile)
        {
          show_growl_flash("Please fill any one of the columns", 'error');
          ev.stopImmediatePropagation();
          result = false;
        }
        return result
      });
    },

    enableClientManager: function () {
      $('#user_company_name').trigger('keyup');
    },

    triggerFocus: function () {
      $('.email').last().focusout();
    },

    onLeave: function (data) {

    }
  };
}(window.jQuery));

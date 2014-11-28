
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
          if(!$('#emails_con .error').is(':visible') && $('#emails_con').find('input[type="text"]').last().val())
          {
            this.email=$('#emails_con input[type=text]').length;
            this.att_name="user[user_emails_attributes]["+this.email+"][email]";
            $('#emails_con li.control-group.closebottom').append('<div class="controls"><input type="text" class="email valid cont-new text input-xlarge" name = '+this.att_name+'><span id="cancel_email"></span></div>');
          }
          $(this).addClass('disabled');
        }
      });
    },

    bindRemoveImageClick: function () {
      $('body').on('click.contact_form', '.remove_image', function(){
        if(confirm(window.App.Contacts.Contact_form.confirm_text))
        {
          $('#emails_con').append('<input name="deleted[]" type="hidden" value='+$(this).data("email")+'>');
          $(this).parent().children("input[type=hidden]").val(1);
          $(this).parent().next().hide(); //This is to remove the hidden id field
          $(this).parent().hide();
          if($('#emails_con').find('.controls:visible').length==0)
          {
            $('#add_new_mail').trigger('click');
            // asdasds
          }
        }
      });
    },

    bindCancelEmailClick: function () {
      $("body").on('click.contact_form', '#cancel_email', function(ev){
        ev.preventDefault();
        $(this).parent().remove();
        if(!$('#cancel_email').length)
          $('#add_new_mail').removeClass('disabled')

        if($('#emails_con').find('.controls:visible').length==0)
        {
          $('#add_new_mail').trigger('click');
        }
        $('.email').trigger('keyup');
      });
    },

    toggleAddNewEmail: function () {
      $('body').on('keyup.contact_form focusout.contact_form', '.email', function(){
        $('#add_new_mail')
          .toggleClass('disabled', !$.trim($('#add_email')
          .parent().parent().prev().find('input[type=text]')
          .last().val()));
        if($('#cancel_email').length && $('#emails_con').
          find('input[type="text"]').last().val() && !$('#emails_con .error').is(':visible'))
          $('#add_new_mail').removeClass('disabled')
      });
    },

    bindErrorFieldChanges: function () {
      $('.remove_image').each(function(rm, rv){
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
      $('.form_for_contact').submit(function (ev) {
        var email = $('#emails_con').find('input[type="text"]:visible').val(),
        twitter = $("#user_twitter_id").val().length,
        phone = $('#phone_work').val().length,
        mobile = $('#phone_mobile').val().length;

        if(!email && !twitter && !phone && !mobile)
        {
          ev.preventDefault();
          show_growl_flash("Please fill any one of the columns", 'error');
        }
      });
    },

    enableClientManager: function () {
      $('#user_company_name').trigger('keyup');
    },

    onLeave: function (data) {

    }
  };
}(window.jQuery));

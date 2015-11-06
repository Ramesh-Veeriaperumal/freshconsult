/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Contacts.Contact_form = window.App.Contacts.Contact_form || {};

(function ($) {
  "use strict";

  window.App.Contacts.Contact_form = {

    onFirstVisit: function (data) {
      this.onVisit(data);
    },
    onVisit: function (data) {
      this.bindGroupValidation();
      this.bindAutocomplete();
      this.bindCompanySelect2();
      this.bindHandlers();
      this.manageNewEmail();
    },

    bindGroupValidation: function() {
      $('#user_phone, #user_mobile, #user_twitter_id, #user_email').addClass('fillone');
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
        minLength: 1,
        select: function (event, ui) {
          $("#user_address").focus();
        },
        open: function () {
          $(".ui-menu").css({'display':'block', 'z-index': 10});
          $(this).removeClass('ui-corner-all');
        }
      }).autocomplete("instance")._renderItem = function (ul, item) {
        return $("<li></li>")
        .data("autocomplete-item", item)
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
      this.enableClientManager();
    },

    bindContactSubmitClick: function () {
      $('body').on('click.contact_form', '#contact_submit', function(ev){
        if($.trim($('#user_company_name').val()) == '') {
          $('#user_client_manager').removeAttr('checked');
        }
      });
    },

    bindCustomerKeyup: function () {
      $("body").on('keyup.contact_form', '#user_company_name', function(ev) {
        var company = this.value.trim();
        if (company != "") {
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
      var self = this;
      $('body').on('click.contact_form', '#add_new_mail', function(ev){
        self.addEmailClick(this);
      });
    },

    addEmailClick: function (obj) {
      if(!$(obj).hasClass('disabled')) {
        if(this.emailWithNoErrors()) {
          this.renderNewEmail();
          $('#emails_con').find('input[type="text"]').last().focus();
        }
        this.manageNewEmail();
      }
    },

    renderNewEmail: function() {
      var email=$('#emails_con input.useremail:last').parent().data("count")+1;
      var att_name="user[user_emails_attributes]["+email+"]";
      $(JST["app/contacts/add_email"]({"email" : email, "att_name" : att_name})).appendTo('ul.user_emails');
    },

    bindPrimaryMakerClick: function () {
      var self = this;
      $('body').on('click.contact_form', '.email-tick.make_primary', function(){
        $(this).twipsy('hide');
        self.buildUEObject($('ul.user_emails li.disabled').first(), 0, $('ul.user_emails li.disabled').first().find(".unverified").length > 0);
        self.buildUEObject($(this).parent(), 1, $(this).parent().find(".unverified").length > 0);
      });
    },

    primaryDisabled: function(primary) {
      if(primary)
        return "disabled"
      else
        return ""
    },

    buildUEObject: function (obj, primary, unverified) {
      var number = obj.data("count");
      var email_id = obj.data("id");
      var value = obj.data("email");
      $(JST["app/contacts/email_template"]({"number" : number, "value" : value, "unverified" : unverified, "email_id" : email_id, "primary" : primary, "disabledclass" : this.primaryDisabled(primary)})).insertAfter(".user_emails li:eq("+number+")");
      obj.remove();
    },

    bindRemoveImageClick: function () {
      var self = this;
      $('body').on('click.contact_form', '.ue_remove_image', function(){
        if(!$(this).hasClass('disabled')){
          if(confirm(window.App.Contacts.Contact_form.confirm_text))
          {
            $(this).siblings("input[type=hidden].ue_destroy").val(1);
            $(this).parent().addClass('destroyed').hide();
            if($('#emails_con').find('input.useremail').length==0)
            {
              self.addEmailClick(this);
            }
          }
        }
        self.manageNewEmail();
      });
    },

    bindCancelEmailClick: function () {
      var self = this;
      $("body").on('click.contact_form', '.ue_cancel_email', function(ev){
        $(this).parent().remove();
        if(!$('ue_cancel_email').length)
          $('#add_new_mail').removeClass('disabled')
        self.manageNewEmail();
      });
    },

    toggleAddNewEmail: function () {
      var self = this;
      $('body').on('keyup.contact_form focusout.contact_form', '.useremail', function(){
        self.manageNewEmail();
      });
    },

    manageNewEmail: function () {
      if( this.emailWithNoErrors() && $('#emails_con li').not('.destroyed').length<5){
          $('#add_new_mail').removeClass('disabled')
        }else{
          $('#add_new_mail').addClass('disabled')
        }

        if($('#emails_con li').not('.destroyed').length >= 5){
          $('.ue_add_email').hide();
        }else{
          $('.ue_add_email').show();
        } 
    },

    emailWithNoErrors: function () {
      return (!$('.useremail.email-error').length && $('input.useremail').last().val())
    },

    enableClientManager: function () {
      $('#user_company_name').trigger('keyup');
    },

    onLeave: function (data) {
      $('body').off('.contact_form');
    }
  };
}(window.jQuery));

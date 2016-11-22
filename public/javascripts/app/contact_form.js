/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Contacts.Contact_form = window.App.Contacts.Contact_form || {};

(function ($) {
  "use strict";

  window.App.Contacts.Contact_form = {
    addedCompanies: [],
    removedCompanies: [],
    editedCompanies: [],
    triggerElement: "",

    onFirstVisit: function (data) {
      this.onVisit(data);
    },
    onVisit: function (data) {
      this.bindGroupValidation();
      this.bindAutocomplete();
      this.bindCompanySelect2();
      this.bindHandlers();
      this.manageNewEmail();
      this.manageNewCompany();
      this.setClientManagerPosition();
    },

    bindGroupValidation: function() {
      $('#user_phone, #user_mobile, #user_twitter_id, #user_email').addClass('fillone');
    },

    bindAutocomplete: function () {
      $('body').on('keyup.contact_form', '.user_company, #user_company_name', function(){
        $(this).autocomplete({
          source: function (request, response) {
              $.ajax({
                  url: "/search/autocomplete/companies",
                  data: {
                      q: request.term
                  },
                  success: function (data) {
                    var $results = [];
                    var companies = data.results.slice(0,10);
                    $.map($(".uc_text"), function(item) {$results.push($(item).text())} );
                    $.map($(".new_company"), function(item) {$results.push($(item).val())} );
                    response($.map(companies,
                      function(item) {
                        var val = escapeHtml(item.value);
                        if ($.inArray(val, $results) == -1){
                          return {
                            label: val,
                            value: item.value
                          }
                        }
                      }));
                  }
              });
          },
          minLength: 1,
          select: function (event, ui) {
            var $addCompany = $("#add_new_company");
            if($addCompany.length) {
              $addCompany.focus();
            }
            else {
              $('#user_client_manager').focus();
            }
          },
          open: function () {
            $(this).autocomplete("widget").css({'display':'block', 'z-index': 1060});
            $(this).removeClass('ui-corner-all');
          }
        }).autocomplete("instance")._renderItem = function (ul, item) {
          return $("<li></li>")
          .data("autocomplete-item", item)
          .append("<a>" + item.label + "</a>")
          .appendTo(ul);
        };
      });
    },

    bindCompanySelect2: function () {
      var self = this,
              select_init_data = {
                tags: self.tags_options.split(","),
                tokenSeparators: [',']
              };
      if(self.create_tag_privilege != true){
        select_init_data['createSearchChoice'] = null;
      }
      $("input[name='user[tag_names]']").select2(select_init_data);
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
      this.addNewCompany();
      this.bindClientManagerClick();
      this.bindDefaultCompanyClick();
      this.bindDeleteCompanyClick();
      this.bindRenameCompanyClick();
    },

    bindContactSubmitClick: function () {
      var self = this;
      $('body').on('click.contact_form', '#contact_submit', function(ev){
        if($("#user_form").valid()) {
          if($.trim($('#user_company_name').first().val()) == '') {
            $('#user_client_manager').removeAttr('checked');
          }

          $("#user_companies [data-new-company='true']").each(function(i, selected){ 
            var company_name = $.trim($(selected).find("input").val());
            if(company_name != "" && ($.inArray(company_name, self.selected_companies) == -1)){
              var obj = self.userCompanyParams($(selected), company_name);
              self.addedCompanies.push(obj);
            }
          });

          $("#user_companies [data-company-edited='true'], [data-company-name-edited='true'], [data-cmanager-edited='true']").not("[data-company-destroyed='true']").each(function(i, selected){ 
            var obj = self.userCompanyParams($(selected), $(selected).find("p").text());
            obj["id"] = $(selected).find("p").data('id');
            self.editedCompanies.push(obj);
          });
          
          $("#user_companies [data-company-destroyed='true']").each(function(i, selected){ 
            var company_name = $(selected).find("p").text();
            if($.inArray(company_name, self.selected_companies) !== -1)
              self.removedCompanies[i] = company_name;
          });

          $("#added_companies").val(self.addedCompanies.toJSON());
          $("#removed_companies").val(String(self.removedCompanies));
          $("#edited_companies").val(self.editedCompanies.toJSON());
        }
      });
    },

    userCompanyParams: function (element, company_name) {
      return { "company_name" : company_name,
        "client_manager" : eval(element.data("client-manager")) || false,
        "default_company" : eval(element.data("default-company")) || false
      }
    },

    bindCustomerKeyup: function () {
      $("body").on('keyup.contact_form', '#user_company_name', function(ev) {
        var company = this.value.trim();
        if (company != "") {
          $('#user_client_manager').removeAttr("disabled");
        } else {
          $('#user_client_manager').removeAttr('checked');
          $('#user_client_manager').prop("disabled", true);
        }
      });
    },

    bindMenuItemClick: function () {
      $('body').on('click.contact_form', ".ui-menu-item", function(ev){
        var add_company_element = $('body').find("#add_new_company");
        if(add_company_element.length != 0) {
          add_company_element.focus();
        }
        else {
          $('#user_client_manager').focus();
        }
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
          if(confirm(self.confirm_text))
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
    },

    addNewCompany: function () {
      var self = this;
      $('body').on('click.contact_form', '#add_new_company', function(ev){
        self.addCompanyTemplate();
        self.manageNewCompany();
      });
    },

    bindClientManagerClick: function () {
      var self = this;
      $('body').on('click.contact_form', ".client_manager", function(){
        $(this).toggleClass("manage unmanage ficon-ticket-thin ficon-ticket");
        var parent = $(this).parents('.uc_list');
        self.toggleEditAttr(parent, "data-cmanager-edited");
        parent.attr("data-client-manager", !eval(parent.attr("data-client-manager")));
      });
    },

    bindDefaultCompanyClick: function () {
      var self = this;
      $('body').on('click.contact_form', '.make_company_default', function() {
        var obj = $("#user_companies [data-default-company='true']");
        obj.find("span.default_company").removeClass("ficon-checkmark-round primary")
                                        .addClass("make_company_default")
                                        .attr("title", self.mark_default_company);
        self.toggleEditAttr(obj, "data-company-edited");
        obj.attr("data-default-company", false);
        $(this).addClass("ficon-checkmark-round primary")
               .removeClass("make_company_default")
               .twipsy('hide')
               .attr("title", self.default_company);
        self.toggleEditAttr($(this).parents('.uc_list'), "data-company-edited");
        $(this).parents('.uc_list').attr("data-default-company", true);

        if (self.is_company_required) {
          $('.uc_list').find('.user_company').removeClass('required');
          $('.uc_list').find('.remove_pad').removeClass('disabled');
          var parent = $(this).parents('.uc_list');
          parent.find('.user_company').addClass('required');
          parent.find('.remove_pad').addClass('disabled');
        }
      });
    },

    toggleEditAttr: function (obj, attrName) {
      if(obj.find("p").length == 1)
        var val = !eval(obj.attr(attrName));
        obj.attr(attrName, val);
    },

    bindDeleteCompanyClick: function () {
      var self = this;
      $('body').on('click.contact_form', '.company_remove', function(){
        $(this).parents('.uc_list').remove();
        self.manageNewCompany();
      });

      $('body').on('click.contact_form', '.company_delete', function() {
        $(this).parents('.uc_list').attr('data-company-destroyed', true)
                                      .addClass('hide');
        if(eval($(this).parents('.uc_list').attr("data-default-company")) || false){
          var obj = $("#user_companies li").not("[data-company-destroyed='true']").first();
          obj.attr("data-default-company", true)
             .attr("data-company-edited", true);
          obj.find(".default_company")
             .addClass("ficon-checkmark-round primary")
             .removeClass("make_company_default")
             .attr("title", self.default_company);
        }
      })
    },

    bindRenameCompanyClick: function () {
      $('body').on("change.contact_form", ".rename_company",function(){
        $("#rename_text").toggleClass("disabled rename_fade");
        if($(this).attr("id") == "rename_label"){
          $("#rename_text").focus();
        }
      });
    },

    manageNewCompany: function () {
      var length = $("#user_companies li").not("[data-company-destroyed='true']").length;
      $('.uc_add_company').toggle(length < 20);
    },

    addCompanyTemplate: function () {
      if(!$(this).hasClass('disabled')) {
          var count = $("#user_companies li").not("[data-company-destroyed='true']").length+1;
          if(count==1) {
            var className = "ficon-checkmark-round primary";
            var company_title = this.default_company;
            var default_comp = true;
          } else {
            var className = "make_company_default";
            var company_title = this.mark_default_company;
            var default_comp = false;
          }
          var client_manager = this.client_manager;

          var required = (this.is_company_required && ($('.companies').children().length < 1))
          $(JST["app/contacts/add_company"]({"count" : count, 
                                             "class_name" : className,
                                             "required" : (required) ? 'required' : '',
                                             "disabled" : (required) ? 'disabled' : '',
                                             "client_manager" : client_manager, 
                                             "company_title" : company_title,
                                             "default_comp" : default_comp})).appendTo('ul.companies');
          $('#user_companies').find('input[type="text"]').last().focus();
        }
    },

    setClientManagerPosition: function() {
      var company_element = $('body').find("#user_company_name").parents("li");
      if(!company_element.next().hasClass('default_client_manager')) {
        var client_manager_element = $(".default_client_manager")
        company_element.after(client_manager_element);
      }
    }

  };
}(window.jQuery));

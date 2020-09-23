var FreshfoneOutgoingCallerID;
(function($) {
  "use strict"
  FreshfoneOutgoingCallerID = function () {
    this.init();
    this.caller_verification_trigger = 0;
    this.request_trigger_count = 0;
    this.phone_number = 0;
    this.callerListItem = $("#caller-list-item").clone();
    this.current_element = "";
    this.slideEffect = { duration: 300, "easing": "easeOutExpo"} ;
  };

  FreshfoneOutgoingCallerID.prototype = {
    init : function(){
      this.bindAllEvents();
    },

    bindAllEvents : function(){
      this.bindVerifyOutgoingCaller();
      this.bindNewOutgoingCaller();
      this.bindAddNewCallerId();
      this.bindBackToCallerIds();
      this.bindCallerIdDelete();
      this.bindDeleteConfirmation();
      this.bindCancelDelete();
      this.bindVerifyOutgoingNumber();
    },
    
    bindVerifyOutgoingCaller : function () {
      var self = this;
      $('body').on("click.caller_id",'#verify-outgoing-caller', function(ev){ 
        if(self.callerListSize() <= 0){
          self.showTemplate("verify-caller-id");
        } 
        else{
          self.showTemplate("manage-caller-ids");
        }
        $("#outgoing-caller-id").trigger("click");
      });
    },

    bindNewOutgoingCaller : function () {
      var self = this;
      $('body').on("click.caller_id",'#new-outgoing-caller', function(ev){ 
        self.showTemplate("verify-caller-id");
        $("#outgoing-caller-id").trigger("click");
      });
    },

    bindAddNewCallerId : function() {
      var self = this;
      $('body').on("click.caller_id","#another-outgoing-caller", function(ev){
         self.showTemplate("verify-caller-id");
      });
    },
    
    bindBackToCallerIds : function(){
      var self = this;
      $('body').on("click.caller_id","#back-to-caller-ids", function(ev){
        if(self.isNumberSettingsPage()){
          $("#outgoing-caller-id").trigger("click");
        }
        else{
          self.showTemplate("manage-caller-ids");
        }
      });
    },

    bindCallerIdDelete : function(){
      var self = this;
      $('body').on("click.caller_id",".caller-delete-icon", function(){
        self.setCurrentElementAndSlide($(this).data("id"));
      });
    }, 

    bindDeleteConfirmation : function(){
      var self = this;
      $('body').on("click.caller_id",".tick-icon-wrap", function(){
          $.ajax({
             type: "POST",
             dataType: "json",
             url: '/phone/caller_id/delete',
             data: {
               'caller_id' : $(this).data("id"),
               'number_sid' : $(this).data("number-sid")
             },
             success: function (data) {
             },
             error: function(data) {

             }
          });

          self.deleteOutgoingCaller($(this).data("id"));         
  
      });
    },

    bindCancelDelete : function(){
      var self = this;
      $('body').on("click.caller_id",".cancel-icon-wrap", function(){   
          self.slideRight($(this).data("id"));
      });
    },

    bindVerifyOutgoingNumber : function(){
      var self = this;
      $('#verify-outgoing-number').on('click',function(){ 
        
        var outgoing_number =  $('.outgoing-number').val();
        
        if(self.firstVerificationAttempt()){
          self.tryVerifyingCallerID(outgoing_number);
        }     
        else{
          self.showCallerIDFormWithError(freshfone.simultaneous_verification_error + " " + self.phone_number );
        }         
      
      });       
    },

    tryVerifyingCallerID : function(number){
      if(this.validatedCallerID(number)){
          this.showOutgoingCallTemplate(number);
          var self = this;
          $.ajax({
               type: "POST",
               dataType: "json",
               url: '/phone/caller_id/validation',
               data: {
                 'number' : number
               },
               success: function (data) { 
                  if(data.code){
                    self.phone_number = data.phone_number;
                    self.showValidationCodeTemplate(data.code);
                    self.clearVerificationInterval();
                    self.setCallVerficationInterval(data.phone_number);  
                  }
                  if(data.error_message){
                    self.showCallerIDFormWithError(data.error_message);
                  }
               },
               error: function (data) {
                self.clearVerificationInterval();
               }
          });  
        }  
      else{
        this.showCallerIDFormWithError(freshfone.invalid_number_message);
      }  
    },

    checkIfCallerIDVerified : function(number){
      this.request_trigger_count++;
      var self = this;
      $.ajax({
         type: "POST",
         dataType: "json",
         url: '/phone/caller_id/verify',
         data: {
           'number' : number
         },
         success: function (data) {
          self.handleSuccessValidation(data,number);
         },
         error: function (data) {

         }
       });
    },

    handleSuccessValidation : function(data,number){
      if(data.caller){
          var caller = data.caller['caller_id'];
          if(number == caller.number){
              this.showTemplate("validation-success");
              this.clearVerificationInterval();
              this.addOutgoingCaller(caller);
              this.addSelect2Option(caller);
          }
      }
      if(this.request_trigger_count >= 20){
          this.showCallerIDFormWithError(freshfone.error_message);
          this.clearVerificationInterval();
      }
    },

    setCallVerficationInterval : function(number){
      var self = this;
      this.caller_verification_trigger = setInterval(function(){
                                      self.checkIfCallerIDVerified(number);
                                    }, 3000);  
    },
    
    clearVerificationInterval : function(){
      clearInterval(this.caller_verification_trigger);
      this.request_trigger_count = 0;
    },

    setCurrentElementAndSlide : function(target_id){
      if(this.current_element){
        this.slideRight(this.current_element);
      }
        this.slideLeft(target_id);
        this.current_element = target_id;
    },

    validatedCallerID : function(number){
      return !((/[a-zA-Z]/.test(number)) || number == "")
    },

    setCallerIdCount : function(size){
      $(".caller_count").html("("+size+")");
    },

    callerListSize : function(){
      return $('.caller-id-list li').length;
    },

    firstVerificationAttempt : function(){
      return this.request_trigger_count == 0 ;
    },

    slideLeft : function(target_id){
      $("#caller-number"+target_id).animate({'right' : "61px" },this.slideEffect);
      $("#caller-delete"+target_id).animate({'right' : "-62px" },this.slideEffect);
    },

    slideRight : function(target_id){
      $("#caller-number"+target_id).animate({'right' : "0px" },this.slideEffect);
      $("#caller-delete"+target_id).animate({'right' : "-127px" },this.slideEffect);
    },

    addSelect2Option : function(caller){
      if(this.isNumberSettingsPage()){
        $('#caller_id').append(new Option(caller.number,caller.id));
        if($("#caller_id option").length == 1){
          $("#caller_id").select2("val",caller.id);
        }
        $('.caller_id_container').show();
        $('.no-number-added').hide();
      }  
    },

    addOutgoingCaller : function(caller){
      if(!this.isNumberSettingsPage()){
        $('.caller-id-list').append(this.callerListItem.tmpl({ id : caller.id , 
                                                               number_sid : caller.number_sid , 
                                                               number : caller.number ,
                                                               delete_text : freshfone.delete_text }) );
        this.setCallerIdCount(this.callerListSize());
      }  
    },

    deleteOutgoingCaller : function(target_id){
      $("#caller-list-item" + target_id).remove();
      this.setCallerIdCount(this.callerListSize());
      if(this.callerListSize() <= 0){
        this.showTemplate("verify-caller-id");
      } 
    },

    showTemplate : function(className){
      $(".error-message").hide();
      $(".caller , .caller-header").hide();
      this.manageCallerHeader(className);
      $("."+className).show();
    },

    manageCallerHeader : function(className){
      if(this.isNumberSettingsPage() || this.callerListSize() <= 0 ){
        $("#default-caller-header").show();
      } 
      else{
        if(className == 'manage-caller-ids'){
          $(".manage-caller-header").show();
        }
        else if(className == 'verify-caller-id'){
          $(".verify-caller-header").show();
        }
        else{
          $("#outgoing-caller-header").show();
        }
      }
    },

    showCallerIDFormWithError : function(message){
      this.showTemplate("verify-caller-id");
      $(".error-message").html(message); 
      $(".error-message").show(); 
    },

    showOutgoingCallTemplate : function(number){
      this.showTemplate("calling-outgoing-number");
      $(".calling-number").html(freshfone.calling + number);
    },

    showValidationCodeTemplate : function(code){
      this.showTemplate("verifying-number");
      $('.validation-code').html(code);
    },

    isNumberSettingsPage : function(){
      return $("#caller_id").hasClass("select2");
    }

  };

}(jQuery));

jQuery(document).ready(function() {
    var freshfoneOutgoingCallerId = new FreshfoneOutgoingCallerID();
});
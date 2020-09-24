window.App = window.App || {};
window.App.Freshfonecallhistory = window.App.Freshfonecallhistory || {};
(function ($) {
  "use strict";
  window.App.Freshfonecallhistory.CallLogs = {
    load: function () {
      this.initializeElements();
      this.setLocationIfUnknown();
      this.bindCreateTicket();
      this.bindChildCalls();
      this.bindDeleteRecordingModal();
      this.bindDeleteRecording();
      this.bindCostSplitUp();
      this.bindPopHover();
    },
    initializeElements: function () {
      this.$freshfoneCallHistory = $('.fresfone-call-history');
    },
    setLocationIfUnknown: function () {
      $(".location_unknown").each(function () {
        var country = countryForE164Number("+" + $(this).data('number'));
        $(this).html(country);
      });
    },
    bindChildCalls: function () {
      var self = this;
      this.$freshfoneCallHistory.on('click.freshfonecallhistory.calllogs', '.child_calls',
       function () {
        var parent = $(this).parents('tr'), 
          $currentNumber = App.Freshfonecallhistory.CallFilter.$currentNumber;

        if ($(this).data('fetch') === undefined) {
          $(this).data('fetch', true);
          parent
            .after("<tr rel='loadingtr'><td colspan='8'><div class='loading-box sloading loading-tiny'></div></td></tr>")
            .addClass('transfer_call');
          self.getChildCalls($(this), $currentNumber);
          
        } else {
          var children_class = parent.attr('id');
          parent.toggleClass('transfer_call');
          $('.' + children_class).toggle();
        }
      });
    },
    getChildCalls: function ($element, $currentNumber) {
      $.ajax({
        url: freshfone.CALL_HISTORY_CHILDREN_PATH,
        dataType: "script",
        data: {
          id : $element.data('id'),
          number_id : $currentNumber.val()
        },
        success: function (script) {
          $("[rel='loadingtr']").remove();
        },
        error: function (data) {
          $("[rel='loadingtr']").remove();
          $element.removeData('fetch');
        }
      });
    },
    bindDeleteRecordingModal:function(){
      this.$freshfoneCallHistory.on('click.freshfonecallhistory.calllogs','.delete_recording_btn',
        function(ev){
          $('#open-delete-recording-confirmation').trigger('click');
          $('#deletion_call_id').val($(this).data('call-id'));          
        }
      );
    },
    bindDeleteRecording:function(){
      $('body').on('click.freshfonecallhistory.calllogs','#recording-deletion-confirmation-submit',
      function(ev){
        ev.preventDefault();
        $('#call-id-'+$('#deletion_call_id').val()).empty().addClass("sloading loading-small curved_border");
        $.ajax({
          url:'/phone/call_history/'+$('#deletion_call_id').val()+'/destroy_recording',
          type:'DELETE',
          success:function(result){
            $('#call-id-'+$('#deletion_call_id').val()).removeClass("sloading loading-small curved_border");
          },
          error:function(jqXHR,textStatus,errorThrown){
          }
        });
      });
    },
    bindCreateTicket: function () {
      this.$freshfoneCallHistory.on('click.freshfonecallhistory.calllogs', '.create_freshfone_ticket',
       function (ev) {
        ev.preventDefault();
        App.Phone.Metrics.setConvertedToTicket();
        if (freshfoneendcall === undefined) { return false; }
        freshfoneendcall.id = $(this).data("id");
        freshfoneendcall.inCall = false;
        freshfoneendcall.callerId = $(this).data( "customer-id");
        freshfoneendcall.callerName = $(this).data("customer-name");
        freshfoneendcall.number = $(this).data("number");
        freshfoneendcall.date = $(this).data("date");
        freshfoneendcall.agent = $(this).data("responder-id");
        freshfoneendcall.directDialNumber = $(this).data("direct-dial-number");
        freshfoneendcall.showEndCallForm();
      });
    },
    bindCostSplitUp: function() {
      var hidePopoverTimer, widgetPopup, hoverPopup;
      $("#call-history-page").on('mouseenter', "span[rel=ff-cost-hover-popover]",function(ev) {
        ev.preventDefault();
        var element = $(this);
        var timeoutDelayShow = setTimeout(function(){
            clearTimeout(hidePopoverTimer);
            hideActivePopovers(ev);
            widgetPopup = element.popover('show');
            hoverPopup = true;
          }, 300);
          element.data('timeoutDelayShow', timeoutDelayShow);

        }).on('mouseleave', "span[rel=ff-cost-hover-popover]",function(ev) {
            clearTimeout($(this).data('timeoutDelayShow'));
            hidePopoverTimer = setTimeout(function() {
              if(widgetPopup) widgetPopup.popover('hide');
              hoverPopup = false;
            }, 300);

       });
      
    },
    bindPopHover: function() {
      var self = this;
      $("span[rel=ff-cost-hover-popover]").livequery(function(){
        $(this).popover({ 
          delayOut: 300,
          trigger: 'manual',
          offset: 5,
          reloadContent: true,
          html: true,
          placement: 'above',
          template: '<div class="dbl_left arrow"></div><div class="ff_hover_card inner"><div class="content ff_cost_splitup"><div></div></div></div>',
          content: function(){
            return self.buildCostSplitup(this);
          }
        }); 
      });
    },
    buildCostSplitup: function (element) {
      var template = $("#freshfone-cost-splitup").clone();
      return template.tmpl({
              "total_duration" : $(element).data("totalDuration"),
              "no_of_unit" : $(element).data("noOfUnit"),
              "pulse_rate" : $(element).data("pulseRate")
            });
    },
    leave: function() {
      $('body').off('.freshfonecallhistory.calllogs');
    }
  };
}(window.jQuery));
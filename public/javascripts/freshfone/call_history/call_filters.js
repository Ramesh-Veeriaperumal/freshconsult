window.App = window.App || {};
window.App.Freshfonecallhistory = window.App.Freshfonecallhistory || {};
(function($){
  "use strict";
  window.App.Freshfonecallhistory.CallFilter = { 
    start: function () {
      this.initializeElements();
      this.bindAllSelect2();
      this.bindChangeEvents();
      this.bindSortingMenu();
      this.settingsForDatePicker();
      this.initSelect2Values();
      this.bindSubmitButton();
      this.bindExport();
      this.bindFormSumbit();
      this.bindPagination();
      this.setFilterData();
      this.setFilterDetails();
      $("#sliding").slide();
      $("#responder").select2();
    },
    initializeElements: function () {
      this.$freshfoneCallHistory = $('.fresfone-call-history');
      this.$filterSortForm = $('#SortFilterCalls');
      this.$filterCondition = this.$filterSortForm.find('[rel=filter]');
      this.$callHistoryBody = this.$freshfoneCallHistory.find(".list-page-body");
      this.$currentPageNumber = this.$filterSortForm.find("input[name=page]");
      this.$filterContainer = this.$freshfoneCallHistory.find(".ff_item");
      this.$currentNumber = this.$filterSortForm.find("input[name=number_id]");
      this.$data_hash = this.$filterSortForm.find("input[name=data_hash]");
      this.$callFilter = $('.call-history-left-filter');
      this.$responder = this.$callFilter.find('#responder');
      this.$callerName = this.$callFilter.find('#callerName');
      this.$requesterId_ffitem = this.$callFilter.find('#requesterName_choices');
      this.$callerId_ffitem = this.$callFilter.find('#callerName_choices');
      this.$groupName = this.$callFilter.find("#groupName");
      this.$groupId_ffitem = this.$callFilter.find('#groupName_choices');
      this.$filterDetails = this.$freshfoneCallHistory.find("#filterdetails");
      this.$fNumberSelect2 = this.$callFilter.find("#ff_number");
      this.$fCallStatusSelect2 = this.$callFilter.find("#ff_call_status");
      this.$filterFreshfoneNumberLabel = this.$freshfoneCallHistory.find(".filter_freshfone_number");
      this.$export_div = $('.call_history_export_div');
      this.filterString = '';
      this.allNumbersId = 0 ;
      this.filteredAgents = [];
      this.filteredAgents_Name = [];
      this.data_hash = [];
      this.isShowingAllNumbers=false;
    },
    bindAllSelect2: function () {
      this.bindFreshfoneNumberSelect2();
      this.bindCallStatusSelect2();
      this.bindRequesterSelect2();
      this.bindCallerSelect2();
      this.bindGroupSelect2();
    },
    bindFreshfoneNumberSelect2: function () {
      var self = this;
      this.$fNumberSelect2.select2({
        dropdownCssClass : 'no-search',
        data: {
          text: 'value',
          results: freshfone.freshfone_number_list},
        formatResult: function (result) {
          var formatedResult = "", ff_number = result.value;
          
          if(result.id==self.allNumbersId){
          return formatedResult +="<b>" + result.value+ "</b></br>";
          } 
          
          if (result.name) {
            formatedResult += "<b>" + result.name + "</b><br>" + ff_number;
          } else {
            formatedResult += "<b>" + result.value + "</b>";
          }

          if (result.deleted) {
            formatedResult += "<i class='muted'> (Deleted)</i>"
          } 
          return formatedResult;
        },
        formatSelection: function (result) {
          self.$fNumberSelect2.attr('fnumber',result.value);
          self.$fNumberSelect2.data('ff_name',result.name || "");
          self.$currentNumber.val(result.id);
         if(result.id==self.allNumbersId){
          self.isShowingAllNumbers=true;
           return result.value;
          }
         else{
          self.isShowingAllNumbers=false;
           return result.name+" ("+result.value+")";
          } 
        }
      });
    },

    bindCallStatusSelect2: function () {
      var self = this;
      this.$fCallStatusSelect2.select2({
        dropdownCssClass : 'no-search',
        data:{
          text: 'value',
          results:freshfone.call_status_list
        },
        formatResult: function (result) {
          return result.value;
        },
        formatSelection: function (result) {
          self.handleGroupView(result);
          self.$fCallStatusSelect2.attr('value',result.call_type)
                             .data('value',result.value);
          return result.value;
        }
      });
    },
    bindRequesterSelect2: function () {
      var self = this;
      this.$responder.on("change", function (data) {
        var responderNames = ($("#responder option:selected").map( function () {return $(this).text()}));
        responderNames = responderNames.toArray().join(', ');
        self.$requesterId_ffitem.attr('value',self.$responder.val());
        self.$requesterId_ffitem.data('value',responderNames);
      });
    },
    bindCallerSelect2: function () {
      var self = this;
      this.bindAutoCompleteSetet2(self.$callerName, freshfone.customer_autocomplete_path, 'Name or Email or Phone',
       function (result) {
          self.$callerName.val(result.value);
          var condition = (result.user_result == undefined) ? 'caller_number_id' : 'customer_id' 
          self.$callerId_ffitem.attr('condition', condition);
          self.$callerId_ffitem.attr('value',result.id);
          self.$callerId_ffitem.data('value',result.value);
          return result.value;
      });
    },
    bindGroupSelect2: function () {
      var self = this;
      this.$groupName.select2({
        placeholder: 'Group',
        allowClear: true,
        data: {
          text: 'value',
          results: freshfone.group_list },
        formatResult: function (result) {
          return result.value;
        },
        formatSelection: function (result) {
          self.$groupName.attr('value',result.id);
          self.$groupName.data('value', result.value);
          return result.value;

        }
      });
    },
    bindChangeEvents: function () {
      var self = this;
      this.$responder.on("change.freshfonecallhistory.callFilter", function () {
        if(this.value) { return }
        self.resetElementvalues(self.$requesterId_ffitem);
      });
      this.$callerName.on("change.freshfonecallhistory.callFilter", function () {
        if(this.value) { return }
        self.resetElementvalues(self.$callerId_ffitem);
      });
      this.$groupName.on("change.freshfonecallhistory.callFilter", function () {
        if(this.value) { return }
        self.resetElementvalues(self.$groupName);
      });
    },
    resetElementvalues: function (element) {
      element.data('value','');
      element.attr('value','');
    },
    bindSortingMenu: function () {
      var self = this;
      this.$freshfoneCallHistory.on("click.freshfonecallhistory.callFilter", ".wf_order_type, .wf_order", 
        function (ev) {
          if(this.className=== 'wf_order'){
             App.Phone.Metrics.order_type=$(this).attr("wf_order");                     
             var order_type = App.Phone.Metrics.order_sort_type==""? "desc": App.Phone.Metrics.order_sort_type;
             App.Phone.Metrics.recordSource($(this).attr("wf_order")+order_type);
             App.Phone.Metrics.push_event();
          }
          if(this.className=== 'wf_order_type'){
             App.Phone.Metrics.order_sort_type=$(this).attr("wf_order_type");
             var order = App.Phone.Metrics.order_type==""? "created_at": App.Phone.Metrics.order_type;
             App.Phone.Metrics.recordSource(order+$(this).attr("wf_order_type"));
             App.Phone.Metrics.push_event();
          }
          ev.preventDefault();
          self.$filterSortForm.find("input[name=" + this.className + "]")
            .val(this.getAttribute(this.className))
            .trigger("change");

          self.$freshfoneCallHistory
            .find("." + this.className + " .ticksymbol").remove();
          $(this).prepend($('<span class="icon ticksymbol"></span>'));

          if (this.className !== 'wf_order_type') { self.setDropdownValue(this); }
      });
    },
    setDropdownValue: function (obj) {
      $(obj)
        .parents('.dropdown:first').find('.filter-name')
        .text($(obj).text());
      if ($(obj).attr('wf_order') != 'created_at' ) {
        this.$export_div.addClass('disabled');
      } else {
        this.$export_div.removeClass('disabled');
      }
    },
    bindSubmitButton: function () {
      var self= this;
      this.$freshfoneCallHistory.on("click.freshfonecallhistory.callFilter","#submitfilter",
        function(ev) {
          App.Phone.Metrics.recordCallHistoryFilterState();
        ev.preventDefault();
        self.getFilterData();
        $("#sliding").trigger("click");
      });
    },

    /* Call History Export methods start */
    bindExport: function () {
      var self = this;
      this.$freshfoneCallHistory.on("click.freshfonecallhistory.callFilter",".export_option",
        function(ev) {
          App.Phone.Metrics.recordSource($(ev.target).attr('data-format'));
          App.Phone.Metrics.push_event();
          ev.preventDefault();
          self.setFilterData();
          self.showProgress();
          $.ajax({
            url : '/phone/call_history/export',
            data : $(self.$filterSortForm).serialize() + '&export_to=' + $(ev.target).attr('data-format'),
            success : function() {
              self.cleanupLoader();
              self.showExportAlerts(self.$export_div.attr("data-success-message") +
                " (" + freshfone.current_user_details.email + ")");
            },
            statusCode: {
              400: function() {
                self.cleanupLoader();
                self.showExportAlerts(self.$export_div.attr("data-range-limit-message"));
              },
              500: function() {
                self.cleanupLoader();
                $("#noticeajax").html("<div>" + self.$export_div.attr("data-error-message") + 
                  " <a href='mailto:support@freshdesk.com' target='_blank'>Click here</a>" + "</div>").show();
                setTimeout(function() {closeableFlash('#noticeajax')}, 5000);
              }
            }
          });
      });
    },

    showExportAlerts: function(message) {
      $("#noticeajax").html("<div>" + message + "</div>").show();
      setTimeout(function() {closeableFlash('#noticeajax');}, 3000);
    },

    showProgress: function(progress) {
      if (progress === undefined) { progress = 0 };
      if (progress >= 1.0) { return; }
      NProgress.set(progress);
      this.showProgress(progress + 0.2);
    },

    cleanupLoader: function() {
      NProgress.done();
      setTimeout(NProgress.remove, 500);
    },

    /* Call History Export methods end */

    bindPagination: function () {
      var self= this;
      this.$freshfoneCallHistory.on("click.freshfonecallhistory.callFilter", ".pagination a", 
        function (ev) {
        ev.preventDefault();
        $.scrollTo('#calls');
        self.$filterSortForm.find("input[name=page]")
          .val(getParameterByName("page", this.href))
          .trigger("change");
      });
    },
    bindFormSumbit: function () {
      var self= this;
      this.$filterSortForm.on("change.freshfonecallhistory.callFilter",function () {
        self.$callHistoryBody.html("<div class='loading-box sloading loading-tiny'></div>");
        $.ajax({
          url: freshfone.CALL_HISTORY_CUSTOM_SEARCH_PATH,
          dataType: "script",
          data: $(this).serializeArray(),
          success: function (script) { 
            self.setFilterDetails();
           }
        });
      });
    },
    setFilterDetails: function() {
      var ff_display_number = this.getDisplayNumber();
      this.$filterFreshfoneNumberLabel.html(ff_display_number);
      this.$filterDetails.html(this.filterString);
    },
    initSelect2Values: function() {
      var cached_ffone_number = getCookie('fone_number_id'), number_object;
      if (cached_ffone_number != undefined){
        number_object = $.grep(freshfone.freshfone_number_list, function (ele) { 
          return ele.id == cached_ffone_number; 
        })[0];
      }
      number_object = number_object || freshfone.freshfone_number_list[0];
      this.$fNumberSelect2.select2('data',number_object);
      this.$fCallStatusSelect2.select2('data',freshfone.call_status_list[0]);
      // this.$responder.select2('data',freshfone.agents_list[0]);
    },
    settingsForDatePicker: function () {
      var datePickerLabels = freshfone.date_picker_labels[0];
      $("#date_range").daterangepicker({
        earliestDate: Date.parse('04/01/2013'),
        latestDate: Date.parse('Today'),
        presetRanges: [
          {text: datePickerLabels['today'], dateStart: 'Today', dateEnd: 'Today' },
          {text: datePickerLabels['yesterday'], dateStart: 'Yesterday', dateEnd: 'Yesterday' },
          {text: datePickerLabels['this_week'], dateStart: 'Today-7', dateEnd: 'Today' },
          {text: datePickerLabels['this_month'], dateStart: 'Today-29', dateEnd: 'Today'}
        ],
        presets: {
          dateRange: datePickerLabels['custom']
        },
        rangeStartTitle: 'From',
        rangeEndTitle: 'To',
        dateFormat: 'dd MM yy',
        closeOnSelect: true,
        onChange: function() {
          $("#date_range").attr("value",$("#date_range").val());
          $("#date_range").data("value",$("#date_range").val());
        }
      });
      $("#date_range").bind('keypress keyup keydown', function(ev) {
        ev.preventDefault();
        return false;
      });
    },
    getFilterData: function () {
      this.setFilterData();
      this.$currentPageNumber.val(1);
      this.$filterSortForm.trigger('change');
    },
    setFilterData: function() {
      var fcondition, container, foperator, fvalues,
      data_hash=[], i = 0, filterString = " Filtered by:  ";

      this.$filterCondition.empty();
      this.$filterContainer.map(function (index, ele) {
        fcondition = this.getAttribute("condition");
        container = this.getAttribute("container");
        foperator  = this.getAttribute("operator");
        fvalues  = this.getAttribute("value");
        if(!$(this).data("value").blank()) {
          filterString +="<li>"+$(this).data("filtername") 
            + " : <strong>" + $(this).data("value")+ "</strong></li>   ";
        }
        if (fvalues.blank() || (fvalues == 0) ) { return true; }
        data_hash.push({
          condition : fcondition,
          operator  : foperator,
          value     : fvalues 
        });
        i++;
      });
      this.$data_hash.val(data_hash.toJSON());
      this.filterString = filterString;
    },
    bindAutoCompleteSetet2: function ($element, path, placeholder, customeFormatSelection) {
      var self = this;
      $element.select2({
        placeholder: placeholder,
        minimumInputLength: 1,
        multiple: false,
        allowClear: true,
        ajax: {
          url: path,
          method: 'GET',
          quietMillis: 1000,
          data: function (term) {
            return {
              q: term
            };
          },
          results: self.ajaxResults
        },
        formatResult: self.select2FormatResult,
        formatSelection: customeFormatSelection
      });
    },
    select2FormatResult: function (result) {
      var userDetails = result.email || result.mobile || result.phone;
          if(userDetails && (userDetails).trim() != "") {
            userDetails = "(" + userDetails + ")" ;
          }
          return "<b>"+ result.value + "</b><br><span class='select2_list_detail'>" + 
                  (userDetails||'') + "</span>"; 
    },
    ajaxResults: function (data, page, query) {
      if (!data.results.length) {
        return { results: [ { value: query.term, id: ""} ] }
      }
      return {results: data.results};
    },
    handleGroupView: function (result) {
      if(result.call_type === "dialed") {
        $(".incomingGroup").hide();
        this.resetElementvalues(this.$groupName);
      } else {
        $(".incomingGroup").show();
      }
    },
    getDisplayNumber: function () {
      var ff_display_number = "<span class='ff_display_name'>";
      if(this.isShowingAllNumbers){
       return ff_display_number +=freshfone.allNumberText+"</span>"
      }
      ff_display_number += this.$fNumberSelect2.data('ff_name').blank() ? 
        this.$fNumberSelect2.attr('fnumber') + "</span>" : 
        this.$fNumberSelect2.data('ff_name') + "</span><span class='ff_display_number'> (" +
          this.$fNumberSelect2.attr('fnumber') + ") </span>";
       return ff_display_number;
    },
    leave: function () {
      $('body').off('.freshfonecallhistory.callFilter');
    }
  };
}(window.jQuery));
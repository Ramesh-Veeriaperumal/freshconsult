window.App = window.App || {};
(function ($) {
  "use strict";

  App.RequesterWidgetConfig = {
    sortableFieldsContainer : "#requester-widget-config-container .widget-field-list.sortable-list",
    select2Container: "#requester-widget-config-container .select2-wrapper",
    select2Tag : "#requester-widget-config-container select.requester-widget-field-choices",
    select2Disabled: "#requester-widget-config-container .disabled-message",
    addFieldIcon: "#requester-widget-config-container .rounded-add-icon",
    configForm : "#requester-widget-config-dialog form",
    maxFields : 7,
    deleted_list:[],


    initialize: function () {
       this.bindTriggers();
    },

    bindTriggers: function () {
      this.attachSelect2Triggers();
      this.attachSortableTrigger();
      this.attachDeleteFieldTrigger();
      this.attachSubmitTrigger();
    },

    attachSortableTrigger: function(){
      $(this.sortableFieldsContainer).sortable({ items: "li", containment: "parent", tolerance: "pointer", handle:".sort_handle_wrapper"});

      $(this.sortableFieldsContainer).bind("sortstart", function(event, ui) {
        ui.placeholder.css("visibility", "visible");
      });
    },

    attachDeleteFieldTrigger: function(){
      var $this = this;
      $($this.sortableFieldsContainer).find('.rounded-minus-icon').live("click", function(){
        // Need a global variable here to store id and type of deleted elements;
        $this.deleted_list.push({"id" : $(this).parent('li').data('id'),
                                  "type" : $(this).parent('li').data('type'), });
        $(this).parent('li').fadeOut(200, function(){
          $this.addDropDownField($(this));
          $(this).remove();
          $this.validateFieldCount();
        });
      });
    },

    attachSelect2Triggers: function () {
      var $this = this;

      $($this.select2Container).addClass("hidden-mode");

      $($this.select2Tag).select2({
        dropdownCssClass: "requester-widget-add",
        forceAbove: true
      });

      $($this.addFieldIcon).click(function(){
         $($this.select2Tag).select2("open");
      });

      $this.attachSelect2SelectTrigger();

      $($this.select2Tag).on("change", function(e) {
          $($this.select2Tag).select2("val","");
      });

      $($this.select2Container).removeClass("hidden-mode");

    },

    attachSelect2SelectTrigger: function(){
      var $this = this;
      $($this.select2Tag).on("select2-selecting", function(e) {

        var id = $(e.object.element).val();
        var label = $(e.object.element).text();
        var type =$(e.object.element).data('type');
        var position = $(e.object.element).data('position');
        $this.deleted_list.each(function(obj,i){
          if(obj.id==id && obj.type== type)
            $this.deleted_list.splice(i, 1);
        });

        if($(e.object.element).data("type") === "contact"){
          $($this.sortableFieldsContainer).append($this.createContactField(id,label,type,position));

        }
        else{
          $($this.sortableFieldsContainer).append($this.createCompanyField(id,label,type,position));
        }

        $this.deleteDropDownField(e.object.element);
        $this.validateFieldCount();
      });
    },

    attachSubmitTrigger: function() {
      var $this = this;
      $($this.configForm).on("submit", function(){
         $this.processForm();
         return true;
      });

    },

    processForm: function (){
      var $this = this;
      var widgetConfig = [];
      var fields =  $(this.sortableFieldsContainer+ " li");
      fields.each(function(i,obj){
        var field  = {
        "id": $(obj).data('id'),
        "type":  $(obj).data('type'),
        "position": i + 1
         }
         widgetConfig.push(field);
      });
      $('input#requester_widget_config').val(JSON.stringify(widgetConfig));
      $('input#deleted_widget_config').val(JSON.stringify($this.deleted_list));

      var url = $($this.configForm).attr("action");
    },

    validateFieldCount: function(){
      var $this = this;
      if( $($this.sortableFieldsContainer).find('li').length < $this.maxFields ){
        $($this.select2Disabled).addClass('hide');
        $($this.select2Container).removeClass('hide');

      }else{
        $($this.select2Container).addClass('hide');
        $($this.select2Disabled).removeClass('hide');
      }

    },

    createContactField: function (fieldId, fieldName, fieldType, fieldPosition) {
      return $('<li data-id="'+fieldId+'" data-position="'+fieldPosition+'"  data-type="'+fieldType+'" data-type="'+fieldType+'"><div class="sort_handle_wrapper"><span class="sort_handle"></span></div><span class="label-wrapper"><span class="ficon-user"></span><span>'+fieldName+'</span></span><i class="rounded-icon rounded-minus-icon"></i></li>');
    },

    createCompanyField: function (fieldId, fieldName, fieldType, fieldPosition) {
      return $('<li data-id="'+fieldId+'" data-position="'+fieldPosition+'" data-type="'+fieldType+'"><div class="sort_handle_wrapper"><span class="sort_handle"></span></div><span class="label-wrapper"><span class="ficon-company"></span><span>'+fieldName+'</span></span><i class="rounded-icon rounded-minus-icon"></i></li>');
    },

    createDropDownField: function (fieldId,fieldType,fieldPosition,fieldLabel) {
        return $('<option data-type="'+fieldType+'" data-position="'+fieldPosition+'" value="'+fieldId+'">'+fieldLabel+'</option>');
    },

    addDropDownField: function(element) {
      var $this = this;
      var id = $(element).data('id');
      var type = $(element).data('type');
      var position = $(element).data('position');
      var label = $(element).text();

      var optionsContainer =  $($this.select2Tag).find('optgroup.'+type);
      var options =  $(optionsContainer).find('option');
      var adjacentOptions = $(options).filter(function(){
                                return $(this).data("position") > position;
                              });

      if(adjacentOptions.length > 0){
        $($this.createDropDownField(id,type,position,label)).insertBefore(adjacentOptions[0]);
      }
      else if(options.length > 0 && $(options[0]).data('position') > position){
        optionsContainer.prepend($this.createDropDownField(id,type,position,label));
      }
      else{
        optionsContainer.append($this.createDropDownField(id,type,position,label));
      }

    },

    deleteDropDownField: function(element) {
      $(element).remove();
    },
  };
}(window.jQuery));

jQuery(document).ready(function(){
   App.RequesterWidgetConfig.initialize();
});

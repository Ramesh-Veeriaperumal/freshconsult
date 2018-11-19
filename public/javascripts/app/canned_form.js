/*jslint browser: true, devel: true */
/*global  App:true */

window.App = window.App || {};
window.App.Support = window.App.Support || {};

(function ($) {
  "use strict";
  var numberOfQuestionsAnswered = 0;
  var focusNextField = true;
  var prevFocusedDiv = null; // flag to check if is scrolling within the div or actually moved out. Will help in  bluring input field
  App.Support.Canned_forms = {
    initializeData: function () {
      this.initLoad();
      this.bindEvents();
    },

    bindEvents: function() {
      var _this = this;
      $('label').on('click',function(event){
        if($(this).siblings().hasClass('canned-form-dropdown')){
        event.preventDefault();
        }
      });
      $('.welcome-note-button').on('click',function(event){
        _this.focus_form_field($(this));
        event.preventDefault();
      });
      $('.paragraph-button').on('click',function(event){
        _this.focus_next_form_field($(this));
        event.preventDefault();
      });
      $('.canned-form-field input').on('blur',function(){
        if($(this).parent().hasClass('canned-form-dropdown')) {
            _this.setCurrentValue($(this).parent().parent());
        }
        else if($(this).hasClass('canned-form-text')){
            _this.setCurrentValue($(this).parent());
        }
        else if($(this).parent().parent().hasClass('canned-form-checkbox')) {
            _this.setCurrentValue($(this).parent().parent().parent());
        }
      });
      $('.canned-form-field textarea').on('blur',function(){
          _this.setCurrentValue($(this).parent());
      });
      $('.canned-form-field *').on('focus',function(){
        var elem = $(this).closest('.canned-form-field');
        if(($(this).hasClass('select2-input'))){
          elem = $('.select2-dropdown-open').closest('.canned-form-field');
        }
        if(!(elem.hasClass('active_form_class'))) {
          _this.setPreviousValue(elem);
          _this.disable_active_form_field();
          _this.scrollToFocus(elem);
          _this.enable_field(elem);
        }
      });
      $('.canned-form-field textarea').on('focus',function(){
        if(!($(this).parent().hasClass('active_form_class'))){
          _this.disable_active_form_field();
          _this.setPreviousValue($(this).parent());
          _this.scrollToFocus($(this).parent());
          _this.enable_field($(this).parent());
        }
      });
      $('select.canned-form-dropdown').on('change',function(){
        if($(this).val()){
          _this.focus_next_form_field($(this));
          $(this).blur();
        }
      });
      $('body').on('keydown', function(e) {
         if(e.which == 13) {
           if($('.welcome-note').hasClass('active_form_class')){
            _this.focus_form_field($('.welcome-note button'));
          }
          else if($('.active_form_class').find('.canned-form-text').length){
            _this.focus_next_form_field($('.active_form_class').find('.canned-form-text'));
            e.preventDefault();
          }
        }
      });
      $("body").on( "click", ".field_not_active", function(){
        if(!$(this).hasClass('welcome-note') && $('.welcome-note').hasClass('active_form_class')){
          $('.welcome-note').removeClass('active_form_class').addClass('field_not_active');
        }
        if(focusNextField && !($(this).hasClass('welcome-note'))){
          _this.disable_active_form_field($(this));
          _this.scrollToFocus($(this));
          _this.enable_field($(this));
        }
        focusNextField = true;
      });
      $('.canned-form-checkbox .btn').on('click',function(e){
        $(this).parent().children().removeClass("active");
        if(($(this).parent().parent().hasClass('active_form_class'))){
          var element = this;
          setTimeout(function(){
            _this.focus_next_form_field($(element).parent());
          },300);
        }
      });
      $(window).on("scroll", function(event) {
        var welcomeNote = $('body').find(".welcome-note");
        var welcomenotetop = welcomeNote.offset().top; // To focus welcome note while scrolling
        if($(window).scrollTop() <100 ){
          _this.reinitStateWelcome(welcomeNote);
          prevFocusedDiv = this;
        }
        $('body').find(".canned-form-field").each(function() { // To focus the canned form fields not while scrolling
          var etop = $(this).offset().top;
          var diff = etop - $(window).scrollTop();
          var eheight = $(this).height() < 300 ? 300 : $(this).height();
          var windowsOffset = Math.abs(window.innerHeight-750)/2;
          // var mobileOffset = Math.abs(window.innerHeight-700)/2;
          var offsetRegion; // = window.outerWidth < 720 ? 100 : (100 + windowsOffset);
          // Temperory fix for mobile - should revisit this
          if(window.outerWidth < 720) {
            offsetRegion = 100;
            eheight = 200;
          }
          else {
            offsetRegion = 100 + windowsOffset;
          }

          // Handling 'active' region with diff - different for devices
          if (diff > offsetRegion && diff < offsetRegion + eheight) { // Offset that's best suitable for focusing the form fields. Can be looked upon later and changed if necessary
            if(prevFocusedDiv !== this || !prevFocusedDiv) {
              _this.reinitState(this);
              if(prevFocusedDiv) {
                $(prevFocusedDiv).find("input, textarea").blur();
              }
              prevFocusedDiv = this;
            }
          }
        });
      });
    },

    initLoad: function(){
      var _this = this;
      _this.scrollToFocus($('.welcome-note')); // tracks active_form_class and scrolls it to view
      _this.disable_all_fields(); // disables all form fields to keep welcome note active
    },

    scrollToFocus: function(element) { // Scrolls the active class into view
      var elOffset = element.offset().top;
      var elHeight = element.height();
      var windowHeight = $(window).height();
      var speed = 300; // scroll speed
      var offset;
      offset = elOffset - (windowHeight / 2);
      if (elHeight < windowHeight) {
        offset = elOffset - (windowHeight / 2);
      }
      else {
        offset = elOffset;
      }
      $('html, body').animate({scrollTop:offset}, speed);
    },

    disable_active_form_field: function(value) { // Function to disable the active field of the form and update its current value
      var element = $('.active_form_class');
      if(element.hasClass('canned-form-field')){
        element.removeClass('active_form_class').addClass('field_not_active');
        if(value){
          this.setCurrentValue(element);
        }
      }
    },

    reinitStateWelcome: function(welcomeNote){ // Function to focus welcome note on scroll
      this.disable_active_form_field();
      if($('.form-field-list').find('.active_form_class').length == 0) {
        welcomeNote.addClass("active_form_class");
      }
    },

    reinitState: function(e) { // Function to focus canned form fields on scroll
      this.disable_field($('body').find(".welcome-note"));
      this.disable_active_form_field(e);

      this.enable_field($(e));
    },

    disable_all_fields: function() { // called to disable all canned-form-fields
      $('.canned-form-field').each(function(field){
        $(this).addClass('field_not_active').removeClass('active_form_class');
      });
    },

    disable_field: function(field) { // Called to defocus one particular field
      if(field.hasClass('canned-form-field')){
        this.setCurrentValue(field);
      }
      field.removeClass("active_form_class").addClass("field_not_active");
    },

    enable_field: function(field){// Called to focus one particular field
      if(field.hasClass('canned-form-field')){
        this.setPreviousValue(field);
      }
      field.addClass("active_form_class").removeClass("field_not_active");
    },

    focus_form_field: function(field) { // Called as an action to focus the first form field from welcome-note on click
      // field.blur();
      var defocus_field = $(field).parent();
      this.disable_field(defocus_field);
      this.scrollToFocus($('.canned-form-field').first());
      this.enable_field($('.canned-form-field').first());
    },

    focus_next_form_field: function(field) { // To defocus the current active form field and focus the next field
      var defocus_field = $(field).parent();
      focusNextField = false; // To prevent toggling-back on 'Next' key press
      if(defocus_field.next().hasClass('canned-form-field')){
        this.disable_field(defocus_field);
        this.scrollToFocus(defocus_field.next());
        this.enable_field(defocus_field.next());
      }
      else {
        this.setCurrentValue($(field).parent());
        $('#footer-content input').focus();
      }
    },
    setPreviousValue: function(field) { //sets the fields' previous value as an attribute to the field - Used later to track progress
      var prev = null;
      var chkbox = field.find('.canned-form-checkbox');
      if(chkbox.length) {
        prev = chkbox.attr('checked');
      } else if(field.find('.canned-form-paragraph').length){
          prev = field.find('textarea').val();
      } else if(field.find('.canned-form-dropdown').length){
          prev = field.find('select').val();
      } else {
          prev = field.find('input').val();
      }

      field.attr('prev-value', prev);

    },

    setCurrentValue: function(field) { // sets the fields' current value as an attribute to the field - Used later to track progress
      var curval = null;
      if(field.find('.canned-form-checkbox').length) {
        curval = field.find('.btn.active > input[type="radio"]').attr('checked');
      } else if(field.find('.canned-form-paragraph').length) {
          curval = field.find('textarea').val();
      } else if(field.find('.canned-form-dropdown').length) {
          curval = field.find('select').val();
      } else if(field.find('.canned-form-text')) {
          curval = field.find('input').val();
      }
      field.attr('cur-value', curval);
      this.trackProgress(field);
    },

    trackProgress: function(field) { // Tracks progress of the field that's in focus
      var prev = field.attr('prev-value');
      var cur = field.attr('cur-value');

      if((cur && !prev) || (cur && cur.trim().length > 0 && (!prev || prev.trim().length == 0))) {
        numberOfQuestionsAnswered = numberOfQuestionsAnswered + 1;
      } else if ((prev && !cur) || (prev && prev.trim().length > 0 && (!cur || cur.trim().length == 0))) {
        numberOfQuestionsAnswered = numberOfQuestionsAnswered - 1;
      }
      this.setProgressBar(field, numberOfQuestionsAnswered);
    },

    setProgressBar: function(field, numberOfQuestionsAnswered) { // Updates progress bar and the answered questions
      $('.progress-text span').text(numberOfQuestionsAnswered);
      var percentage = (numberOfQuestionsAnswered/$('.canned-form-field').length) * 100;
      $('.progress').css('width',percentage+'%');
      field.attr('prev-value', field.attr('cur-value'));
    }

  };
}(window.$));

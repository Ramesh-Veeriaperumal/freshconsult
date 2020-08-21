window.App = window.App || {};
window.App.Admin = window.App.Admin || {};

(function ($) {
  'use strict';

  App.Admin.fbAdminConfig = {
    STRICT_RULE_TYPE: '1',
    OPTIMAL_RULE_TYPE: '2',
    BROAD_RULE_TYPE: '3',

    init: function () {
      this.unbindEvents();
      this.bindEvents();
      this.setupUIState();
    },

    setupUIState: function () {
      var _this = this,
        $doc = $(document),
        $primary_toggle_switch = $doc.find('#primary_toggle_switch'),
        $import_visitor_post_checkbox = $doc.find('#social_ticket_rule__import_visitor_posts'),
        $import_page_post_checkbox = $doc.find('#social_ticket_rule__import_company_comments'),
        $enable_threading_radio = $doc.find('#same_ticket_threading'),
        $disable_threading_radio = $doc.find('#new_ticket_threading'),
        $keyword_container = $doc.find('.keyword_container'),
        $threading_container = $doc.find('.threading_container');

      const CURRENT_RULE = $doc.find('#social_ticket_rule__rule_type').val();

      $('.social_ticket_rule_includes').select2({
        tags: [],
        tokenSeparators: [','],
        formatNoMatches: function () {
          return '  ';
        }
      });

      // Removing name attrib. from element to avoid submitting value while form
      // sumbit as toggle-switch button has been introduced purely for UX.
      $primary_toggle_switch.prop('name', '');

      switch (CURRENT_RULE) {

        // case _this.STRICT_RULE_TYPE i.e., toggle disabled state is handled in template
        case _this.OPTIMAL_RULE_TYPE:
          $primary_toggle_switch.prop('checked', true);
          $import_visitor_post_checkbox.prop('disabled', false);
          $disable_threading_radio.click().trigger('change');

          var keywordsList = $doc
            .find('.optimal-rules-container #s2id_social_ticket_rule__includes')
            .select2('data');

          if (keywordsList.length) {
            $doc.find('#toggle_keywords').prop('checked', true);
            $doc.find('.social_ticket_rule_includes').show();
          } else {
            $doc.find('.optimal-rules-container #s2id_social_ticket_rule__includes')
              .select2('val', '')
              .hide();
          }
          $threading_container.hide();
          break;

        case _this.BROAD_RULE_TYPE:
          $primary_toggle_switch.prop('checked', true);
          // It is implicit in backend that BROAD_RULE_TYPE will include both 'visitor'
          // and 'page' posts hence this value isn't persisted during form submit for this 
          // rule type. As part of UX revamp we're showing these in UI for better user clarity.
          $import_visitor_post_checkbox.click();
          $import_page_post_checkbox.click();

          $enable_threading_radio.click();
          $import_visitor_post_checkbox.prop('disabled', true);
          $('#import_visitor_posts_text').toggleClass('muted');

          $doc.find('.optimal-rules-container #s2id_social_ticket_rule__includes')
            .select2('val', '')
            .hide();
          $keyword_container.hide();
          break;
      }

      if (!$import_page_post_checkbox.prop('checked')) {
        $('.keyword_wrapper').fadeOut('slow', 'linear');
      }

    },

    bindEvents: function () {
      var _this = this,
        $doc = $(document),
        $import_visitor_post_checkbox = $doc.find('#social_ticket_rule__import_visitor_posts'),
        $import_page_post_checkbox = $doc.find('#social_ticket_rule__import_company_comments'),
        $rule_settings_container = $doc.find('#ticket_rules'),
        $select2_container = $doc.find('.optimal-rules-container #s2id_social_ticket_rule__includes'),
        $ticket_rule_type = $doc.find('#social_ticket_rule__rule_type'),
        $disable_threading_radio = $doc.find('#new_ticket_threading'),
        $keyword_container = $doc.find('.keyword_container'),
        $threading_container = $doc.find('.threading_container');

      $doc.on('change.fbAdminEvents', '#primary_toggle_switch', function () {
        if (this.checked) {
          $import_visitor_post_checkbox.prop('checked', true);
          $import_page_post_checkbox.prop('checked', true).trigger('change');
          $disable_threading_radio.trigger('click');
          $doc.find('#toggle_keywords').trigger('change');

          $rule_settings_container.fadeIn('slow', 'linear').css('display', 'block');
          $select2_container.hide();
          $ticket_rule_type.val(_this.OPTIMAL_RULE_TYPE);
        } else {
          $rule_settings_container.fadeOut('slow', 'linear').css('display', 'block');
          $ticket_rule_type.val(_this.STRICT_RULE_TYPE);
          $('#toggle_keywords').prop('checked', false);
        }
      });

      $doc.on('change.fbAdminEvents', '#social_ticket_rule__import_visitor_posts', function () {
        if (!this.checked) {
          $('#new_ticket_threading').click();
          $ticket_rule_type.val(_this.OPTIMAL_RULE_TYPE);
        } else {
          _this.assign_rule_type();
        }
        this.checked && $ticket_rule_type.val(_this.OPTIMAL_RULE_TYPE);
      });

      $doc.on('change.fbAdminEvents', '#social_ticket_rule__import_company_comments', function () {
        var $keyboard_wrapper = $('.keyword_wrapper');
        if (this.checked) {
          $keyboard_wrapper.fadeIn('slow', 'linear');
          $('#new_ticket_threading').trigger('click');
          $ticket_rule_type.val(_this.OPTIMAL_RULE_TYPE);

          if ($import_visitor_post_checkbox.prop('checked')) {
            $ticket_rule_type.val(_this.BROAD_RULE_TYPE);
          }
        } else {
          $import_visitor_post_checkbox.prop('disabled', false);
          $keyboard_wrapper.fadeOut('slow', 'linear');
        }
      });

      $('.threading').on('change', function () {

        switch (this.id) {
          case 'same_ticket_threading':
            $import_visitor_post_checkbox.prop('checked', true).prop('disabled', true);
            $('#import_visitor_posts_text').addClass('muted');
            // $('#new_ticket_filter_mentions_container').hide()
            // $('#same_ticket_filter_mentions_container').show()
            $ticket_rule_type.val(_this.BROAD_RULE_TYPE);
            $('#toggle_keywords').prop('checked', false);
            $('.optimal-rules-container #s2id_social_ticket_rule__includes').select2('val', '').hide();
            $threading_container.fadeIn('slow', 'linear').css('display', 'block');
            $keyword_container.fadeOut('slow', 'linear').css('display', 'block');
            break;

          case 'new_ticket_threading':
            $import_visitor_post_checkbox.prop('disabled', false);
            $('#import_visitor_posts_text').removeClass('muted');
            $ticket_rule_type.val(_this.OPTIMAL_RULE_TYPE);
            $keyword_container.fadeIn('slow', 'linear').css('display', 'block');
            $threading_container.fadeOut('slow', 'linear').css('display', 'block');
            break;
        }
      });

      $('#toggle_keywords').on('change', function () {
        if (this.checked) {
          // adding default filter suggestions when toggle is turned on
          var default_keywords = $('.optimal-rules-container #default_keywords').val().split(',');
          $('.optimal-rules-container #s2id_social_ticket_rule__includes').select2('val', default_keywords).show();
        } else {
          // disabled toggle means keyword filter shouldn't apply hence we're cleaning values
          $('.optimal-rules-container #s2id_social_ticket_rule__includes').select2('val', '').hide();
        }
      });
    },

    unbindEvents: function () {
      $(document).off('.fbAdminEvents');
    },

    assign_rule_type: function () {
      var _this = this;
      var $ticket_rule_type = $('#social_ticket_rule__rule_type');
      var $visitor_post_toggle = $('#social_ticket_rule__import_visitor_posts');
      var $page_post_toggle = $('#social_ticket_rule__import_company_comments');

      if ($page_post_toggle.prop('checked')
        && $visitor_post_toggle.prop('checked')
        && $('#same_ticket_threading').prop('checked')) {

        $ticket_rule_type.val(_this.BROAD_RULE_TYPE);

      } else if (!$('#primary_toggle_switch').prop('checked')) {
        $ticket_rule_type.val(_this.STRICT_RULE_TYPE);
      } else {
        $ticket_rule_type.val(_this.OPTIMAL_RULE_TYPE);
      }
    }
  };

}(window.jQuery));

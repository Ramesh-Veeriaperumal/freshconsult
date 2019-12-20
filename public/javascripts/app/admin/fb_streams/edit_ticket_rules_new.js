
  (function ($) {
    "use strict";
    const CURRENT_RULE = $('#social_ticket_rule__rule_type').val(),
      STRICT_RULE_TYPE = '1',
      OPTIMAL_RULE_TYPE = '2',
      BROAD_RULE_TYPE = '3';

    $(document).ready(function () {
      var $visitor_post_toggle = $('#social_ticket_rule__import_visitor_posts'),
        $page_post_toggle = $('#social_ticket_rule__import_company_comments'),
        $ticket_rules = $('#ticket_rules'),
        $ticket_rule_type = $('#social_ticket_rule__rule_type'),
        $primary_toggle_switch = $('#primary_toggle_switch');

      $(".social_ticket_rule_includes").select2({
        tags: [],
        tokenSeparators: [","],
        formatNoMatches: function () {
          return "  ";
        }
      });

      // Removing name attrib. from toggle-switch to ignore while submitting form
      // as toggle-switch button has been introduced purely for better UX.
      $primary_toggle_switch.prop('name', '').trigger('change');

      // Setting UI states based on "rule_type" info. on initial page load
      switch (CURRENT_RULE) {
        // case STRICT_RULE_TYPE:
        //   break;

        case OPTIMAL_RULE_TYPE:
          $primary_toggle_switch.prop('checked', true).trigger('change');
          $visitor_post_toggle.prop('disabled', false);
          var keywords = $('.optimal-rules-container #s2id_social_ticket_rule__includes').select2('data');
          $('#new_ticket_threading').click().trigger('change');
          if (keywords.length) {
            $('#toggle_keywords').prop('checked', true);
            $('.social_ticket_rule_includes').show();
          } else {
            $('.optimal-rules-container #s2id_social_ticket_rule__includes').select2('val', '').hide();
          }
          break;

        case BROAD_RULE_TYPE:
          $primary_toggle_switch.prop('checked', true).trigger('change');
          $visitor_post_toggle.prop('checked', true);
          $page_post_toggle.click();
          $('#same_ticket_threading').prop('checked', true);
          $visitor_post_toggle.prop('disabled', true);
          $('#import_visitor_posts_text').toggleClass('muted');
          $('.optimal-rules-container #s2id_social_ticket_rule__includes').select2('val', '').hide();
          $('.keyword_container').hide();
          break;
      }

      if (!$page_post_toggle.prop('checked')) {
        $('.keyword_wrapper').fadeOut("slow", "linear");
      }

      // Event handlers registration

      $primary_toggle_switch.on('change', function () {

        if (this.checked) {
          $visitor_post_toggle.prop('checked', true);
          $page_post_toggle.prop('checked', true).trigger('change');
          $('#new_ticket_threading').trigger('click');

          $ticket_rules.fadeIn("slow", "linear").css('display', 'block');
          $('.optimal-rules-container #s2id_social_ticket_rule__includes').hide();
          $ticket_rule_type.val(OPTIMAL_RULE_TYPE);
        } else {
          $ticket_rules.fadeOut("slow", "linear").css('display', 'block');
          $ticket_rule_type.val(STRICT_RULE_TYPE);
        }
      });

      // Event handlers registration
      $visitor_post_toggle.on('change', function () {
        if (!this.checked) {
          $('#new_ticket_threading').click();
          $ticket_rule_type.val(OPTIMAL_RULE_TYPE);
        } else {
          assign_rule_type();
        }
        this.checked && $ticket_rule_type.val(OPTIMAL_RULE_TYPE);
      });

      $page_post_toggle.on('change', function () {
        var $keyboard_wrapper = $('.keyword_wrapper');
        if (this.checked) {
          $keyboard_wrapper.fadeIn("slow", "linear");
          $('#new_ticket_threading').trigger('click');
          $ticket_rule_type.val(OPTIMAL_RULE_TYPE);

          if ($visitor_post_toggle.prop('checked')) {
            $ticket_rule_type.val(BROAD_RULE_TYPE);
          }
        } else {
          $visitor_post_toggle.prop('disabled', false);
          $keyboard_wrapper.fadeOut("slow", "linear");
        }
      });

      $('.threading').on('change', function () {
        var $keyword_container = $('.keyword_container');

        switch (this.id) {
          case "same_ticket_threading":
            $visitor_post_toggle.prop('checked', true).prop('disabled', true);
            $('#import_visitor_posts_text').addClass('muted');
            $ticket_rule_type.val(BROAD_RULE_TYPE);
            $('#toggle_keywords').prop('checked', false);
            $('.optimal-rules-container #s2id_social_ticket_rule__includes').select2('val', '').hide();
            $keyword_container.fadeOut("slow", "linear").css('display', 'block');
            break;

          case "new_ticket_threading":
            $visitor_post_toggle.prop('disabled', false);
            $('#import_visitor_posts_text').removeClass('muted');
            $ticket_rule_type.val(OPTIMAL_RULE_TYPE);
            $keyword_container.fadeIn("slow", "linear").css('display', 'block');
            break;
        }
      });

      $('#toggle_keywords').on('change', function () {
        if (this.checked) {
          // adding default filter suggestions when toggle is turned on
          var default_keywords = $('.optimal-rules-container #default_keywords').val().split(",");
          $('.optimal-rules-container #s2id_social_ticket_rule__includes').select2('val', default_keywords).show();
        } else {
          // disabled toggle means keyword filter shouldn't apply hence we're cleaning values
          $('.optimal-rules-container #s2id_social_ticket_rule__includes').select2('val', '').hide();
        }
      });

    });

    // Due to UX revamp, rule types are now assigned based on multiple combination of choices

    function assign_rule_type() {
      var $ticket_rule_type = $('#social_ticket_rule__rule_type');
      var $visitor_post_toggle = $('#social_ticket_rule__import_visitor_posts');
      var $page_post_toggle = $('#social_ticket_rule__import_company_comments');

      if ($page_post_toggle.prop('checked')
        && $visitor_post_toggle.prop('checked')
        && $('#same_ticket_threading').prop('checked')) {

        $ticket_rule_type.val(BROAD_RULE_TYPE);

      } else if (!$('#primary_toggle_switch').prop('checked')) {
        $ticket_rule_type.val(STRICT_RULE_TYPE);
      } else {
        $ticket_rule_type.val(OPTIMAL_RULE_TYPE);
      }
    }

  })(jQuery);

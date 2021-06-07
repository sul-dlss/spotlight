# frozen_string_literal: true

module Spotlight
  module TestFeaturesHelpers
    def fill_in_typeahead_field(opts = {})
      type = opts[:type] || 'twitter'
      # Poltergeist / Capybara doesn't fire the events typeahead.js
      # is listening for, so we help it out a little:
      page.execute_script <<-EOF
        $("[data-#{type}-typeahead]:visible").val("#{opts[:with]}").trigger("input");
        $("[data-#{type}-typeahead]:visible").typeahead("open");
        $(".tt-suggestion").click();
      EOF

      find('.tt-suggestion', text: opts[:with], match: :first).click
    end

    ##
    # For typeahead "prefetched" fields, we need to wait for a resolved selector
    # before proceeding.
    def fill_in_prefetched_typeahead_field(opts)
      type = opts[:type] || 'twitter'
      # Poltergeist / Capybara doesn't fire the events typeahead.js
      # is listening for, so we help it out a little:
      find(opts[:wait_for]) if opts[:wait_for]
      page.execute_script <<-EOF
        $("[data-#{type}-typeahead]:visible").val("#{opts[:with]}").trigger("input");
        $("[data-#{type}-typeahead]:visible").typeahead("open");
        $(".tt-suggestion").click();
      EOF
    end

    # just like #fill_in_typeahead_field, but wait for the
    # form fields to show up on the page too
    def fill_in_solr_document_block_typeahead_field(opts)
      fill_in_typeahead_field(opts)
      expect(page).to have_css('li[data-resource-id="' + opts[:with] + '"]')
    end

    def add_widget(type)
      click_add_widget

      # click the item + image widget
      expect(page).to have_css("button[data-type='#{type}']")
      find("button[data-type='#{type}']").click
    end

    def click_add_widget
      if all('.st-block-replacer').blank?
        expect(page).to have_css('.st-block-addition')
        first('.st-block-addition').click
      end
      expect(page).to have_css('.st-block-replacer')
      first('.st-block-replacer').click
    end

    def save_page
      page.execute_script <<-EOF
        SirTrevor.getInstance().onFormSubmit();
      EOF
      click_button('Save changes')
      # verify that the page was created
      expect(page).not_to have_selector('.alert-danger')
      expect(page).to have_selector('.alert-info', text: 'page was successfully updated')
    end

    RSpec::Matchers.define :have_breadcrumbs do |*expected|
      match do |actual|
        errors = []
        errors << 'Unable to find breadcrumbs' unless actual.has_css? '.breadcrumb'

        breadcrumbs = expected.dup

        actual.within('.breadcrumb') do
          last = breadcrumbs.pop
          breadcrumbs.each do |e|
            errors << "Unable to find breadcrumb #{e}" unless actual.has_link? e
          end

          errors << "Unable to find breadcrumb #{last}" unless actual.has_content? last
          errors << "Expected #{last} not to be a link" if actual.has_link? last
        end

        errors.empty?
      end

      failure_message do |actual|
        "expected that #{actual.all('.breadcrumb li').map(&:text).join(' / ')} would include #{expected.join(' / ')}"
      end
    end
  end
end

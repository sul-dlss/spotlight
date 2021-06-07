# frozen_string_literal: true

module Spotlight
  ##
  # Page title helpers
  module TitleHelper
    def curation_page_title(title = nil)
      page_title t(:'spotlight.curation.header'), title
    end

    def configuration_page_title(title = nil)
      page_title t(:'spotlight.configuration.header'), title
    end

    def page_title(section, title = nil)
      title ||= t(:'.header', default: '').presence

      head_content = t(:'spotlight.html_admin_title', section: section, title: title) if section && title
      head_content ||= section || title
      set_html_page_title(head_content)

      html_content = safe_join([
        section.presence,
        (tag.small(title) if title.present?)
      ].compact, "\n")

      tag.h1(html_content, class: 'page-header')
    end

    # rubocop:disable Naming/AccessorMethodName
    def set_html_page_title(title = nil)
      @page_title = strip_tags(t(:'spotlight.html_title', title: title || t(:'.title', default: :'.header'), application_name: application_name)).html_safe
    end
    # rubocop:enable Naming/AccessorMethodName
  end
end

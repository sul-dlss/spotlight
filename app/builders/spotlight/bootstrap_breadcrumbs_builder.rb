# frozen_string_literal: true

module Spotlight
  # The BootstrapBreadcrumbsBuilder is a Bootstrap compatible breadcrumb builder.
  # It provides basic functionalities to render a breadcrumb navigation according to Bootstrap's conventions.
  #
  # BootstrapBreadcrumbsBuilder accepts a limited set of options:
  #
  # You can use it with the :builder option on render_breadcrumbs:
  #     <%= render_breadcrumbs :builder => Spotlight::BootstrapBreadcrumbsBuilder %>
  #
  class BootstrapBreadcrumbsBuilder < BreadcrumbsOnRails::Breadcrumbs::Builder
    include ActionView::Helpers::OutputSafetyHelper

    def render
      return '' if @elements.blank?

      @context.tag.ul(class: 'breadcrumb') do
        safe_join(@elements.uniq.map { |e| render_element(e) })
      end
    end

    def render_element(element)
      current = @context.current_page?(compute_path(element)) || element.options&.dig(:current)

      html_class = 'active' if current

      @context.tag.li(class: "breadcrumb-item #{html_class}") do
        @context.link_to_unless(current, element_label(element), compute_path(element), element.options&.except(:current))
      end
    end

    private

    def element_label(element)
      @context.tag.span(class: 'truncated-value') { compute_name(element) }
    end
  end
end

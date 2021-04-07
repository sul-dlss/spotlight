# frozen_string_literal: true

module Spotlight
  ##
  # Helpers for building polymorphic links within the exhibit context
  module CrudLinkHelpers
    def cancel_link(model, link, link_to_options = {})
      link_to action_default_value(model, :cancel), link, link_to_options
    end

    def view_link(model, *args)
      link_to_options = args.extract_options!
      link = args.first || [spotlight, model]
      link_to action_default_value(model, :view), link, link_to_options
    end

    def exhibit_view_link(model, *args)
      link_to_options = args.extract_options!
      link = args.first || [spotlight, model.exhibit, model]
      link_to action_default_value(model, :view), link, link_to_options
    end

    def create_link(model, *args)
      link_to_options = args.extract_options!
      link = args.first || polymorphic_path([spotlight, model], action: :new)
      link_to action_default_value(model), link, link_to_options
    end

    def exhibit_create_link(model, *args)
      link_to_options = args.extract_options!
      link = args.first || polymorphic_path([spotlight, current_exhibit, model], action: :new)
      link_to action_default_value(model), link, link_to_options
    end

    def edit_link(model, *args)
      link_to_options = args.extract_options!
      link = args.first || polymorphic_path([spotlight, model], action: :edit)
      link_to action_default_value(model), link, link_to_options
    end

    def exhibit_edit_link(model, *args)
      link_to_options = args.extract_options!
      link = args.first || polymorphic_path([spotlight, model.exhibit, model], action: :edit)
      link_to action_default_value(model), link, link_to_options
    end

    def delete_link(model, *args)
      link_to_options = args.extract_options!
      link = args.first || [spotlight, model]
      default_options = { method: :delete, data: { confirm: action_default_value(model, :destroy_are_you_sure) } }
      link_to action_default_value(model, :destroy), link, default_options.merge(link_to_options)
    end

    def exhibit_delete_link(model, *args)
      link_to_options = args.extract_options!
      link = args.first || [spotlight, model.exhibit, model]
      default_options = { method: :delete, data: { confirm: action_default_value(model, :destroy_are_you_sure) } }
      link_to action_default_value(model, :destroy), link, default_options.merge(link_to_options)
    end

    def action_label(model, action)
      action_default_value model, action
    end

    def nav_link(name = nil, options = nil, html_options = nil, &block)
      # rubocop:disable Style/ParallelAssignment
      # (Note: this is copied from upstream in Rails)
      html_options, options, name = options, name, block if block_given?
      # rubocop:enable Style/ParallelAssignment

      html_options ||= {}

      tag.li(class: 'nav-item') do
        if block_given?
          link_to(options, nav_link_html_options(options, html_options), &block)
        else
          link_to(name, options, nav_link_html_options(options, html_options), &block)
        end
      end
    end

    private

    def nav_link_html_options(options, html_options)
      active = html_options.key?(:active) ? html_options[:active] : current_page?(options)
      html_options.merge(class: [html_options[:class], 'nav-link', ('active' if active)].join(' '))
    end

    # rubocop:disable Metrics/MethodLength
    def action_default_value(object, key = nil)
      object_model = convert_to_model(object)

      key ||= if object_model
                object_model.persisted? ? :edit : :create
              else
                :view
              end

      case object_model
      when ActsAsTaggableOn::Tag
        model = :tag
        object_name = :tag
      when Symbol, String
        model = object_model
        object_name = object_model
      else
        model = object_model.class.model_name.human
        object_name = object_model.class.model_name.i18n_key
      end

      defaults = []
      defaults << :"helpers.action.#{object_name}.#{key}"
      defaults << :"helpers.action.#{key}"
      defaults << "#{key.to_s.humanize} #{model}"
      I18n.t(defaults.shift, model: model.downcase, default: defaults)
    end
    # rubocop:enable Metrics/MethodLength
  end
end

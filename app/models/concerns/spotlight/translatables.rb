# frozen_string_literal: true

module Spotlight
  # Mixin for adding translatable ActiveRecord accessors
  module Translatables
    extend ActiveSupport::Concern

    class_methods do
      def translates(*attr_names)
        attr_names.map(&:to_sym)
        attr_names.map(&method(:define_translated_attr_reader))
      end

      ##
      # Set up a reader for the specified attribute that uses the I18n backend,
      # and defaults to the ActiveRecord value
      def define_translated_attr_reader(attr_name)
        # Define a dynamic method for translating database-backed attributes,
        # falling back to the database information as needed.
        #
        # Note: the empty string is provided as the final fallback to avoid i18n blowing
        # up on nil attributes.
        define_method(:"#{attr_name}") do
          send("translated_#{attr_name}", default: [attr_translation(attr_name), ''])
        end

        # Define an accessor that gets the value of the attribute in a given locale,
        # returning `nil` for untranslated values.
        #
        # Note: For the default locale, we actually want to dig into the database,
        # because that is the source of truth for the data.
        define_method(:"translated_#{attr_name}") do |default: [], **options|
          default = Array.wrap(default)
          default.prepend(attr_translation(attr_name)) if I18n.locale == I18n.default_locale
          I18n.t(attr_name, scope: slug, default: default, **options).presence
        end
      end
    end

    private

    ##
    # Will return the default ActiveRecord value for the value
    def attr_translation(attr_name)
      self[attr_name]
    end
  end
end

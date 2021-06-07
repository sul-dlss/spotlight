# frozen_string_literal: true

module Spotlight
  module Resources
    ##
    # A PORO to construct a solr hash for a given IiifManifest
    class IiifManifest
      attr_reader :collection

      def initialize(attrs = {})
        @url = attrs[:url]
        @manifest = attrs[:manifest]
        @collection = attrs[:collection]
        @solr_hash = {}
      end

      def to_solr(exhibit: nil)
        @exhibit = exhibit if exhibit

        add_document_id
        add_label
        add_thumbnail_url
        add_full_image_urls
        add_manifest_url
        add_image_urls
        add_metadata
        add_collection_id
        solr_hash
      end

      def with_exhibit(e)
        @exhibit = e
      end

      def compound_id
        Digest::MD5.hexdigest("#{exhibit.id}-#{url}")
      end

      private

      attr_reader :url, :manifest, :exhibit, :solr_hash

      delegate :blacklight_config, to: :exhibit

      def add_document_id
        solr_hash[exhibit.blacklight_config.document_model.unique_key.to_sym] = compound_id
      end

      def add_collection_id
        solr_hash[collection_id_field] = [collection.compound_id] if collection
      end

      def collection_id_field
        Spotlight::Engine.config.iiif_collection_id_field
      end

      def add_manifest_url
        solr_hash[Spotlight::Engine.config.iiif_manifest_field] = url
      end

      def add_thumbnail_url
        return unless thumbnail_field && manifest['thumbnail'].present?

        solr_hash[thumbnail_field] = manifest['thumbnail']['@id']
      end

      def add_full_image_urls
        return unless full_image_field && full_image_url

        solr_hash[full_image_field] = full_image_url
      end

      def add_label
        return unless title_fields.present? && manifest&.label

        Array.wrap(title_fields).each do |field|
          solr_hash[field] = metadata_class.new(manifest).label
        end
      end

      def add_image_urls
        solr_hash[tile_source_field] = image_urls
      end

      def add_metadata
        solr_hash.merge!(manifest_metadata)
        sidecar.update(data: sidecar.data.merge(manifest_metadata))
      end

      def manifest_metadata
        metadata = metadata_class.new(manifest).to_solr
        return {} if metadata.blank?

        create_sidecars_for(*metadata.keys)

        metadata.each_with_object({}) do |(key, value), hash|
          next unless (field = exhibit_custom_fields[key])

          hash[field.field] = value
        end
      end

      def create_sidecars_for(*keys)
        missing_keys(keys).each do |k|
          exhibit.custom_fields.create! label: k, readonly_field: true
        end
        @exhibit_custom_fields = nil
      end

      def missing_keys(keys)
        custom_field_keys = exhibit_custom_fields.keys.map(&:downcase)
        keys.reject do |key|
          custom_field_keys.include?(key.downcase)
        end
      end

      def exhibit_custom_fields
        @exhibit_custom_fields ||= exhibit.custom_fields.index_by do |value|
          value.label
        end
      end

      def image_urls
        @image_urls ||= resources.map do |resource|
          next unless resource && !resource.service.empty?

          image_url = resource.service['@id']
          image_url << '/info.json' unless image_url.downcase.ends_with?('/info.json')
          image_url
        end
      end

      def full_image_url
        resources.first.try(:[], '@id')
      end

      def resources
        @resources ||= sequences
                       .flat_map(&:canvases)
                       .flat_map(&:images)
                       .flat_map(&:resource)
      end

      def sequences
        manifest.try(:sequences) || []
      end

      def thumbnail_field
        blacklight_config.index.thumbnail_field
      end

      def full_image_field
        Spotlight::Engine.config.full_image_field
      end

      def tile_source_field
        blacklight_config.show.tile_source_field
      end

      def title_fields
        Spotlight::Engine.config.iiif_title_fields || blacklight_config.index&.title_field
      end

      def sidecar
        @sidecar ||= document_model.new(id: compound_id).sidecar(exhibit)
      end

      def document_model
        exhibit.blacklight_config.document_model
      end

      def metadata_class
        Spotlight::Engine.config.iiif_metadata_class.call
      end

      ###
      #  A simple class to map the metadata field
      #  in a IIIF document to label/value pairs
      #  This is intended to be overriden by an
      #  application if a different metadata
      #  strucure is used by the consumer
      class Metadata
        def initialize(manifest)
          @manifest = manifest
        end

        def to_solr
          metadata_hash.merge(manifest_level_metadata)
        end

        def label
          return unless manifest&.label

          Array(json_ld_value(manifest.label)).map { |v| html_sanitize(v) }.first
        end

        private

        attr_reader :manifest

        def metadata
          manifest&.metadata || []
        end

        def metadata_hash
          return {} if metadata.blank?
          return {} unless metadata.is_a?(Array)

          metadata.each_with_object({}) do |md, hash|
            next unless md['label'] && md['value']

            label = Array(json_ld_value(md['label'])).first

            hash[label] ||= []
            hash[label] += Array(json_ld_value(md['value'])).map { |v| html_sanitize(v) }
          end
        end

        def manifest_level_metadata
          manifest_fields.each_with_object({}) do |field, hash|
            next unless manifest.respond_to?(field) &&
                        manifest.send(field).present?

            hash[field.capitalize] ||= []
            hash[field.capitalize] += Array(json_ld_value(manifest.send(field))).map { |v| html_sanitize(v) }
          end
        end

        def manifest_fields
          %w[attribution description license]
        end

        # rubocop:disable Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        def json_ld_value(value)
          case value
          # In the case where multiple values are supplied, clients must use the following algorithm to determine which values to display to the user.
          when Array
            # IIIF v2, multivalued monolingual, or multivalued multilingual values

            # If none of the values have a language associated with them, the client must display all of the values.
            if value.none? { |v| v.is_a?(Hash) && v.key?('@language') }
              value.map { |v| json_ld_value(v) }
            # If any of the values have a language associated with them, the client must display all of the values associated with the language that best
            # matches the language preference.
            elsif value.any? { |v| v.is_a?(Hash) && v['@language'] == default_json_ld_language }
              value.select { |v| v.is_a?(Hash) && v['@language'] == default_json_ld_language }.map { |v| v['@value'] }
            # If all of the values have a language associated with them, and none match the language preference, the client must select a language
            # and display all of the values associated with that language.
            elsif value.all? { |v| v.is_a?(Hash) && v.key?('@language') }
              selected_json_ld_language = value.find { |v| v.is_a?(Hash) && v.key?('@language') }

              value.select { |v| v.is_a?(Hash) && v['@language'] == selected_json_ld_language['@language'] }
                   .map { |v| v['@value'] }
            # If some of the values have a language associated with them, but none match the language preference, the client must display all of the values
            # that do not have a language associated with them.
            else
              value.select { |v| !v.is_a?(Hash) || !v.key?('@language') }.map { |v| json_ld_value(v) }
            end
          when Hash
            # IIIF v2 single-valued value
            if value.key? '@value'
              value['@value']
            # IIIF v3 multilingual(?), multivalued(?) values
            # If all of the values are associated with the none key, the client must display all of those values.
            elsif value.keys == ['none']
              value['none']
            # If any of the values have a language associated with them, the client must display all of the values associated with the language
            # that best matches the language preference.
            elsif value.key? default_json_ld_language
              value[default_json_ld_language]
            # If some of the values have a language associated with them, but none match the language preference, the client must display all
            # of the values that do not have a language associated with them.
            elsif value.key? 'none'
              value['none']
            # If all of the values have a language associated with them, and none match the language preference, the client must select a
            # language and display all of the values associated with that language.
            else
              value.values.first
            end
          else
            # plain old string/number/boolean
            value
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity

        def html_sanitize(value)
          return value unless value.is_a? String

          html_sanitizer.sanitize(value)
        end

        def html_sanitizer
          @html_sanitizer ||= Rails::Html::FullSanitizer.new
        end

        def default_json_ld_language
          Spotlight::Engine.config.default_json_ld_language
        end
      end
    end
  end
end

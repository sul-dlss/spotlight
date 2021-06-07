# frozen_string_literal: true

module Spotlight
  ##
  # SolrDocument mixins to add ActiveModel shims and indexing methods
  module SolrDocument
    extend ActiveSupport::Concern

    include Spotlight::SolrDocument::Finder
    include GlobalID::Identification

    included do
      use_extension(Spotlight::SolrDocument::UploadedResource, &:uploaded_resource?)
    end

    ##
    # Class-level methods
    module ClassMethods
      def build_for_exhibit(id, exhibit, attributes = {})
        new(unique_key => id).tap do |doc|
          doc.sidecar(exhibit).tap { |x| x.assign_attributes(attributes) }.save! # save is a nop if the sidecar isn't modified.
        end
      end

      def reindex(id)
        find(id).reindex
      rescue Blacklight::Exceptions::RecordNotFound => e
        Rails.logger.debug "Unable to find document #{id}: #{e}"
      end

      def reindex_all
        find_each(&:reindex)
      end

      def exhibit_slug_field
        "#{Spotlight::Engine.config.solr_fields.prefix}spotlight_exhibit_slugs#{Spotlight::Engine.config.solr_fields.string_suffix}"
      end

      def solr_field_for_tagger(tagger)
        :"#{solr_field_prefix(tagger)}tags#{Spotlight::Engine.config.solr_fields.string_suffix}"
      end

      def visibility_field(exhibit)
        :"#{solr_field_prefix(exhibit)}public#{Spotlight::Engine.config.solr_fields.boolean_suffix}"
      end

      def resource_type_field
        :"#{Spotlight::Engine.config.solr_fields.prefix}spotlight_resource_type#{Spotlight::Engine.config.solr_fields.string_suffix}"
      end

      def solr_field_prefix(exhibit)
        "#{Spotlight::Engine.config.solr_fields.prefix}#{exhibit.class.model_name.param_key}_#{exhibit.to_param}_"
      end
    end

    def update(current_exhibit, new_attributes)
      attributes = convert_incoming_attributes(new_attributes)

      custom_data = attributes.delete('sidecar')
      tags = attributes.delete('exhibit_tag_list')
      resource_attributes = attributes.delete('uploaded_resource')

      sidecar(current_exhibit).update(custom_data) if custom_data

      # NOTE: this causes a save
      current_exhibit.tag(sidecar(current_exhibit), with: tags, on: :tags) if tags

      update_exhibit_resource(resource_attributes) if uploaded_resource?
    end

    def save
      reindex
    end

    def update_exhibit_resource(resource_attributes)
      return unless resource_attributes && resource_attributes['url']

      uploaded_resource.upload.update image: resource_attributes['url']
    end

    def reindex
      # no-op reindex implementation
    end

    def sidecars
      Spotlight::SolrDocumentSidecar.where(document_id: id, document_type: self.class.to_s)
    end

    def sidecar(exhibit)
      sidecars.find_or_initialize_by exhibit: exhibit, document_id: id, document_type: self.class.to_s
    end

    def to_solr
      { self.class.unique_key.to_sym => id }.reverse_merge(sidecars.inject({}) { |acc, elem| acc.merge(elem.to_solr) })
                                            .merge(tags_to_solr)
                                            .merge(exhibits_to_solr)
    end

    def make_public!(exhibit)
      sidecar(exhibit).public!
    end

    def make_private!(exhibit)
      sidecar(exhibit).private!
    end

    def private?(exhibit)
      !public?(exhibit)
    end

    def public?(exhibit)
      sidecar(exhibit).public?
    end

    def uploaded_resource?
      self[self.class.resource_type_field].present? &&
        self[self.class.resource_type_field].include?('spotlight/resources/uploads')
    end

    def attribute_present?(*_args)
      false
    end

    protected

    def tags_to_solr
      h = {}

      sidecars.each do |sidecar|
        h[self.class.solr_field_for_tagger(sidecar.exhibit)] = nil

        sidecar.taggings.includes(:tag, :tagger).map do |tagging|
          key = self.class.solr_field_for_tagger(tagging.tagger)
          h[key] ||= []
          h[key] << tagging.tag.name
        end
      end
      h
    end

    def exhibits_to_solr
      slugs = sidecars.map(&:exhibit).map(&:slug)

      {
        self.class.exhibit_slug_field => slugs
      }
    end

    def convert_incoming_attributes(attributes)
      attributes = attributes.stringify_keys

      # convert blank strings to nil
      attributes = deep_transform_values(attributes, &:presence)

      # trim excess nils from arrays
      deep_compact(attributes)
    end

    def deep_transform_values(object, &block)
      # Available in Rails 6
      if object.respond_to?(:deep_transform_values)
        object.deep_transform_values(&block)
      else
        _deep_transform_values(object, &block)
      end
    end

    # Shimmed from Rails 6
    def _deep_transform_values(object, &block)
      case object
      when Hash
        object.transform_values { |value| deep_transform_values(value, &block) }
      when Array
        object.map { |e| deep_transform_values(e, &block) }
      else
        yield(object)
      end
    end

    def deep_compact(object)
      case object
      when Hash
        object.transform_values { |value| deep_compact(value) }
      when Array
        object.compact
      else
        object
      end
    end
  end
end

ActsAsTaggableOn::Tagging.after_destroy do |obj|
  if obj.tagger.is_a?(Spotlight::Exhibit) && obj.taggable.is_a?(Spotlight::SolrDocumentSidecar)
    obj.tagger.blacklight_config.document_model.reindex(obj.taggable.document_id)
  end
end

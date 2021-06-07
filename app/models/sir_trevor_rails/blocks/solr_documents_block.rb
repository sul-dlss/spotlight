# frozen_string_literal: true

module SirTrevorRails
  module Blocks
    ##
    # Multi-up document viewer with text block
    class SolrDocumentsBlock < SirTrevorRails::Block
      include Textable
      include Displayable
      attr_reader :solr_helper

      def with_solr_helper(solr_helper)
        @solr_helper = solr_helper
      end

      def each_document
        return to_enum(:each_document) unless block_given?

        items.each do |i|
          document = documents.detect { |doc| doc.id == i[:id] }
          i[:iiif_tilesource_base] = i.fetch(:iiif_tilesource, '').sub('/info.json', '')
          yield i, document if document
        end
      end

      def documents
        @documents ||= begin
          doc_ids = items.pluck(:id)
          _, documents = solr_helper.controller.send(:search_service).fetch(doc_ids)
          documents
        end
      end

      def documents?
        each_document.any?
      end

      def primary_caption?
        primary_caption_field.present? && show_primary_caption?
      end

      def show_primary_caption?
        ActiveModel::Type::Boolean.new.cast(send(:'show-primary-caption'))
      end

      def document_caption(presenter, caption_field, default: nil)
        caption_field ||= default

        return unless caption_field
        return presenter.heading if caption_field == Spotlight::PageConfigurations::DOCUMENT_TITLE_KEY

        presenter.field_value(solr_helper.blacklight_config.index_fields[caption_field] || Blacklight::Configuration::NullField.new(caption_field))
      end

      def secondary_caption?
        secondary_caption_field.present? && show_secondary_caption?
      end

      def show_secondary_caption?
        ActiveModel::Type::Boolean.new.cast(send(:'show-secondary-caption'))
      end

      def zpr_link?
        zpr_link == 'true'
      end

      def primary_caption_field
        val = send(:'primary-caption-field')
        val.presence
      end

      def secondary_caption_field
        val = send(:'secondary-caption-field')
        val.presence
      end
    end
  end
end

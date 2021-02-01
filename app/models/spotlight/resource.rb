# frozen_string_literal: true

module Spotlight
  ##
  # Exhibit resources
  class Resource < ActiveRecord::Base
    class_attribute :indexing_pipeline, default: (Spotlight::Etl::Pipeline.new do |pipeline|
      pipeline.sources = [Spotlight::Etl::Sources::IdentitySource]
      pipeline.transforms = [
        reject_blank: Spotlight::Etl::Transforms::RejectBlank,
        reject_missing: Spotlight::Etl::Transforms::RejectMissingUniqueId,
        apply_exhibit_metadata: Spotlight::Etl::Transforms::ApplyExhibitMetadata,
        apply_application_metadata: Spotlight::Etl::Transforms::ApplyApplicationMetadata,
        apply_pipeline_metadata: Spotlight::Etl::Transforms::ApplyPipelineMetadata
      ]
      pipeline.loaders = [Spotlight::Etl::SolrLoader]
    end)

    extend ActiveModel::Callbacks
    define_model_callbacks :index

    class_attribute :weight

    belongs_to :exhibit
    has_many :solr_document_sidecars
    has_many :events, as: :resource

    serialize :data, Hash

    # bust any caches after indexing data
    after_index :touch_exhibit!

    ##
    # Persist the record to the database, and trigger a reindex to solr
    #
    # @param [Hash] All arguments will be passed through to ActiveRecord's #save method
    def save_and_index(*args)
      save(*args) && reindex_later
    end

    ##
    # Enqueue an asynchronous reindexing job for this resource
    def reindex_later
      Spotlight::ReindexJob.perform_later(self)
    end

    def document_model
      exhibit&.blacklight_config&.document_model
    end

    concerning :Indexing do
      ##
      # Index the result of {#to_solr} into the index in batches of {#batch_size}
      #
      # @return [Integer] number of records indexed
      def reindex(**args, &block)
        i = 0
        run_callbacks :index do
          indexing_pipeline.call(Spotlight::Etl::Context.new(self, commit: true, **args)) do |data|
            i += 1
            block&.call(data)
          end
        end

        i
      end

      def estimated_size(**args)
        indexing_pipeline.estimated_size(Spotlight::Etl::Context.new(self, **args))
      end

      private

      def touch_exhibit!
        exhibit&.touch
      end
    end
  end
end

# frozen_string_literal: true

module Spotlight
  module SolrDocument
    ##
    # Finder methods for SolrDocuments
    module Finder
      extend ActiveSupport::Concern

      ##
      # Class level finder methods for documents
      module ClassMethods
        def find(id)
          solr_response = index.find(id)
          solr_response.documents.first
        end

        def index
          @index ||= blacklight_config.repository_class.new(blacklight_config)
        end

        def find_each(&block)
          return to_enum(:find_each) unless block_given?

          start = 0
          search_params = { q: '*:*', fl: 'id', facet: false }
          response = index.search(search_params.merge(start: start))

          while response.documents.present?
            response.documents.each(&block)
            start += response.documents.length
            response = index.search(search_params.merge(start: start))
          end
        end

        protected

        def blacklight_config
          @conf ||= Spotlight::Engine.blacklight_config
        end
      end

      # Returns true if +comparison_object+ is the same exact object, or +comparison_object+
      # is of the same type and +self+ has an ID and it is equal to +comparison_object.id+.
      #
      # Note that new records are different from any other record by definition, unless the
      # other record is the receiver itself. Besides, if you fetch existing records with
      # +select+ and leave the ID out, you're on your own, this predicate will return false.
      #
      # Note also that destroying a record preserves its ID in the model instance, so deleted
      # models are still comparable.
      def ==(other)
        super ||
          (other.instance_of?(self.class) &&
            id &&
            other.id == id)
      end

      def blacklight_solr
        self.class.index.connection
      end
    end
  end
end

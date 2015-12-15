module Spotlight
  module SolrDocument
    ##
    # Solr indexing strategy using Solr's Atomic Updates
    module AtomicUpdates
      def reindex
        data = hash_for_solr_update(to_solr)

        return if data.empty?

        Spotlight.index_writer.update params: { commitWithin: 500 }, data: data.to_json, headers: { 'Content-Type' => 'application/json' }
      end

      private

      def hash_for_solr_update(data)
        Array.wrap(data).map { |doc| convert_document_to_atomic_update_hash(doc) }.reject { |x| x.length <= 1 }
      end

      def convert_document_to_atomic_update_hash(doc)
        doc.each_with_object({}) do |(k, v), hash|
          hash[k] = if k.to_sym == self.class.unique_key.to_sym
                      v
                    else
                      { set: v }
                    end
        end
      end
    end
  end
end

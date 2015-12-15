module Spotlight
  module Indexer
    ##
    # Local writer strategy for updating an index
    # using the default Blacklight configuration
    class LocalWriter
      delegate :update, to: :index

      def index
        @index ||= RSolr.connect(Blacklight.connection_config)
      end
    end
  end
end

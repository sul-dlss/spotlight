require 'spotlight/version'

##
# Spotlight
module Spotlight
  autoload :Config, 'spotlight/config'
  autoload :Base, 'spotlight/base'
  autoload :Controller, 'spotlight/controller'
  autoload :Catalog, 'spotlight/catalog'

  # Namespace for index writing strategies
  module Indexer
    extend ActiveSupport::Autoload
    autoload :LocalWriter
  end

  def self.config(&block)
    @config ||= Engine::Configuration.new
    yield @config if block
    @config
  end

  def self.index_writer
    @index_writer ||= config.index_writer.new
  end
end

require 'spotlight/engine'

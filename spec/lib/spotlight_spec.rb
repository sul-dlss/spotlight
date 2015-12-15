require 'spec_helper'

describe Spotlight do
  its(:index_writer) { should be_instance_of Spotlight::Indexer::LocalWriter }
end

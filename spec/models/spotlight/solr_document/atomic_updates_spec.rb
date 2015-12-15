require 'spec_helper'

describe Spotlight::SolrDocument::AtomicUpdates, type: :model do
  let(:blacklight_solr) { double }
  subject do
    ::SolrDocument.new.extend(described_class)
  end

  before do
    allow(Spotlight.index_writer).to receive_messages(index: blacklight_solr)
  end

  describe '#reindex' do
    before do
      allow(subject).to receive_messages(to_solr: { id: 'doc_id', a: 1, b: 2 })
    end

    it 'sends an atomic update request' do
      expected = {
        params: { commitWithin: 500 },
        data: [{ id: 'doc_id', a: { set: 1 }, b: { set: 2 } }].to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
      expect(blacklight_solr).to receive(:update).with(expected)
      subject.reindex
    end

    it 'cowardlies refuse to index a document if the only value is an id' do
      allow(subject).to receive_messages(to_solr: { id: 'doc_id' })
      expect(blacklight_solr).not_to receive(:update)
      subject.reindex
    end
  end
end

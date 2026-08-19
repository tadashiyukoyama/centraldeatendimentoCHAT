require 'rails_helper'

RSpec.describe Openjarvis::RemoteAttachmentFetcher do
  it 'fetches an allowlisted public HTTPS attachment with bounded SSRF-safe options' do
    tempfile = Tempfile.new(['openjarvis-media', '.jpg'], binmode: true)
    tempfile.write('sanitized-image-bytes')
    tempfile.rewind
    result = SafeFetch::Result.new(tempfile: tempfile, filename: 'example.jpg', content_type: 'image/jpeg')
    blob = instance_double(ActiveStorage::Blob)
    allow(SafeFetch).to receive(:fetch).and_yield(result)
    allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob)

    expect(described_class.new('https://media.example.test/example.jpg').fetch!).to eq(blob)
    expect(SafeFetch).to have_received(:fetch).with(
      'https://media.example.test/example.jpg',
      hash_including(max_bytes: 20.megabytes, allowed_content_type_prefixes: include('image/', 'audio/'))
    )
    expect(ActiveStorage::Blob).to have_received(:create_and_upload!).with(
      io: tempfile, filename: 'example.jpg', content_type: 'image/jpeg'
    )
  ensure
    tempfile&.close!
  end

  it 'rejects non-HTTPS and credential-bearing URLs before fetching' do
    allow(SafeFetch).to receive(:fetch)

    ['http://media.example.test/file.jpg', 'https://user:secret@media.example.test/file.jpg'].each do |url|
      expect { described_class.new(url).fetch! }.to raise_error(Openjarvis::ApiError) do |error|
        expect(error.code).to eq('invalid_remote_attachment_url')
      end
    end
    expect(SafeFetch).not_to have_received(:fetch)
  end

  it 'classifies unavailable remote media as retryable without exposing the remote error' do
    allow(SafeFetch).to receive(:fetch).and_raise(SafeFetch::FetchError, 'private upstream detail')

    expect do
      described_class.new('https://media.example.test/file.jpg').fetch!
    end.to raise_error(Openjarvis::ApiError) do |error|
      expect(error).to have_attributes(code: 'remote_attachment_unavailable', retryable: true)
      expect(error.message).not_to include('private upstream detail')
    end
  end
end

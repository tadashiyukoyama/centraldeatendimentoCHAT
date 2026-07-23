require 'rails_helper'

RSpec.describe Whatsapp::Evolution::ProvisioningService do
  let(:account) { create(:account) }
  let(:client) { instance_double(Whatsapp::Evolution::ApiClient) }

  before do
    allow(Whatsapp::Evolution::Configuration).to receive(:validate!).and_return(true)
    allow(Whatsapp::Evolution::ApiClient).to receive(:new).and_return(client)
  end

  it 'creates a pending server-side provisioning and returns only the QR result' do
    qr_code = Base64.strict_encode64("\x89PNG\r\n\x1A\ncontent".b)
    allow(client).to receive(:create_instance).and_return(
      'qrcode' => { 'base64' => qr_code }
    )

    result = described_class.new(account: account, inbox_name: 'Finance').perform

    expect(result.qr_code).to eq("data:image/png;base64,#{qr_code}")
    expect(result.provisioning).to be_waiting_qr
    expect(result.provisioning.instance_token).to be_present
    expect(result.provisioning.webhook_secret).to be_present
  end

  it 'does not fail when a QR webhook updates the provisioning before the create response returns' do
    qr_code = Base64.strict_encode64("\x89PNG\r\n\x1A\ncontent".b)
    allow(client).to receive(:create_instance) do
      account.whatsapp_evolution_provisionings.last.update!(
        status: :waiting_qr,
        last_seen_at: Time.current
      )
      { 'qrcode' => { 'base64' => qr_code } }
    end

    result = described_class.new(account: account, inbox_name: 'Finance').perform

    expect(result.provisioning).to be_waiting_qr
    expect(result.qr_code).to eq("data:image/png;base64,#{qr_code}")
  end

  it 'does not regress a state advanced by a connection webhook' do
    qr_code = Base64.strict_encode64("\x89PNG\r\n\x1A\ncontent".b)
    allow(client).to receive(:create_instance) do
      account.whatsapp_evolution_provisionings.last.update!(
        status: :connecting,
        last_seen_at: Time.current
      )
      { 'qrcode' => { 'base64' => qr_code } }
    end

    result = described_class.new(account: account, inbox_name: 'Finance').perform

    expect(result.provisioning).to be_connecting
  end

  it 'attempts remote compensation and records a sanitized failure when creation is uncertain' do
    error = Whatsapp::Evolution::ApiClient::Error.new(
      'Evolution API is unavailable',
      code: 'evolution_unavailable'
    )
    allow(client).to receive(:create_instance).and_raise(error)
    allow(client).to receive(:delete_instance).and_return(true)

    expect do
      described_class.new(account: account, inbox_name: 'Finance').perform
    end.to raise_error(
      Whatsapp::Evolution::ApiClient::Error,
      'Evolution API is unavailable'
    )

    provisioning = account.whatsapp_evolution_provisionings.last
    expect(provisioning).to be_failed
    expect(provisioning.last_error_code).to eq('evolution_unavailable')
    expect(client).to have_received(:delete_instance)
  end

  it 'records a failure safely when a webhook changed the lock version during an uncertain creation' do
    error = Whatsapp::Evolution::ApiClient::Error.new(
      'Evolution API is unavailable',
      code: 'evolution_unavailable'
    )
    allow(client).to receive(:create_instance) do
      account.whatsapp_evolution_provisionings.last.update!(
        status: :waiting_qr,
        last_seen_at: Time.current
      )
      raise error
    end
    allow(client).to receive(:delete_instance).and_return(true)

    expect do
      described_class.new(account: account, inbox_name: 'Finance').perform
    end.to raise_error(
      Whatsapp::Evolution::ApiClient::Error,
      'Evolution API is unavailable'
    )

    expect(account.whatsapp_evolution_provisionings.last).to be_failed
    expect(client).to have_received(:delete_instance)
  end

  it 'compensates the remote instance and preserves the original error when failure persistence also fails' do
    error = Whatsapp::Evolution::ApiClient::Error.new(
      'Evolution API is unavailable',
      code: 'evolution_unavailable'
    )
    created_provisioning = nil
    allow(Whatsapp::Evolution::ApiClient).to receive(:new) do |provisioning:|
      created_provisioning ||= provisioning
      client
    end
    allow(client).to receive(:create_instance) do
      allow(created_provisioning).to receive(:record_failure!).and_raise(
        ActiveRecord::StaleObjectError.new(created_provisioning, 'update')
      )
      raise error
    end
    allow(client).to receive(:delete_instance).and_return(true)

    expect do
      described_class.new(account: account, inbox_name: 'Finance').perform
    end.to raise_error(
      Whatsapp::Evolution::ApiClient::Error,
      'Evolution API is unavailable'
    )

    expect(client).to have_received(:delete_instance)
  end
end

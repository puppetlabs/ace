# frozen_string_literal: true

require 'spec_helper'
require 'ace/error'

RSpec.describe ACE::Error do
  let(:instance) {
    described_class.new('failed', 'module/error_type')
  }

  it { expect(instance).to be_a_kind_of(RuntimeError) }

  it { expect(instance.msg).to eq('failed') }

  it 'returns the error as a hash' do
    expect(instance.to_h).to eq(
      'kind' => 'module/error_type',
      'msg' => 'failed',
      'details' => {}
    )
  end

  it 'returns the error as a json string' do
    expect(instance.to_json).to eq(
      '{"kind":"module/error_type","msg":"failed","details":{}}'
    )
  end
end

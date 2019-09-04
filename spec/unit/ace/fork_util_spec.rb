# frozen_string_literal: true

require 'spec_helper'
require 'ace/fork_util'

# Integration level tests, to prove out functionality
RSpec.describe ACE::ForkUtil do
  describe "#isolate" do
    context "when everything works out" do
      it 'returns the result' do
        return_value = described_class.isolate do
          "test string"
        end
        expect(return_value).to eq "test string"
      end

      it 'isolates block from global scope' do
        # rubocop:disable Style/GlobalVars
        $global = 'string_outside'

        described_class.isolate do
          $global = 'string_inside'
        end

        expect($global).to eq 'string_outside'
        # rubocop:enable Style/GlobalVars
      end
    end

    context "when errors occur" do
      it 'exception thrown when the block returns invalid JSON' do
        expect {
          described_class.isolate do
            Float::NAN
          end
        }.to raise_error(RuntimeError, /NaN not allowed in JSON/)
      end

      it 'ACE exception thrown when the block raises an ACE error' do
        expect {
          described_class.isolate do
            raise ACE::Error.new('my message', 'demo/demo')
          end
        }.to raise_error(ACE::Error, /my message/)
      end

      it 'invalid JSON is correctly returned as a string' do
        return_value = described_class.isolate do
          '1. 2. 3. [. "test" : 123. ]'
        end
        expect(return_value).to eq '1. 2. 3. [. "test" : 123. ]'
      end

      it "an empty response is correctly returned as empty string" do
        return_value = described_class.isolate do
          ''
        end
        expect(return_value).to eq ''
      end

      it "a `nil` response is correctly returned as `nil`" do
        return_value = described_class.isolate do
          nil
        end
        expect(return_value).to be_nil
      end
    end

    describe "fork failures" do
      before do
        allow(described_class).to receive(:fork).and_return(nil)
      end

      it "exits the process" do
        expect { described_class.isolate {} }.to raise_error SystemExit
      end
    end

    describe 'premature fork exit' do
      let(:reader) { instance_double(IO, 'reader') }
      let(:writer) { instance_double(IO, 'writer') }

      before do
        allow(described_class).to receive(:fork).and_return(true)
        allow(Process).to receive(:wait).with(true)
        allow(IO).to receive(:pipe).and_return([reader, writer])
        allow(writer).to receive(:close)
        # the forked process can go away without returning any output
        allow(reader).to receive(:readlines).with('').and_return([])
      end

      it 'raises a fork_util error' do
        expect { described_class.isolate {} }.to raise_error ACE::Error, /spawned process returned no result/
      end
    end
  end
end

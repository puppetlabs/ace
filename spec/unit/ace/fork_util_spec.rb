# frozen_string_literal: true

require 'spec_helper'
require 'ace/fork_util'

# Integration level tests, to prove out functionality
RSpec.describe ACE::ForkUtil do
  describe "#isolate" do
    context "The function follows the happy path" do
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

    context "The function runs into 'special' behaviour" do
      it 'exception thrown when the block returns invalid JSON' do
        expect {
          described_class.isolate do
            Float::NAN
          end
        }.to raise_error(RuntimeError, /NaN not allowed in JSON/)
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
    end
  end
end

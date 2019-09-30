# frozen_string_literal: true

require 'spec_helper'
require 'ace/file_mutex'
require 'timeout'

RSpec.describe ACE::FileMutex do
  let(:lock_file) { 'spec/fixtures/test.lock' }
  let(:mutex) { described_class.new(lock_file) }
  let(:lock_content) { [] }

  before do
    File.delete(lock_file) if File.exist?(lock_file)
  end

  after do
    File.delete(lock_file) if File.exist?(lock_file)
  end

  describe '#with_read_lock' do
    it 'successully creates a file lock' do
      foo = mutex.with_read_lock do
        lock_content
      end

      expect(File).to exist(lock_file)
      expect(foo).to eq(lock_content)
    end

    it 'allows for multiple shared (read) locks to access the content' do
      p1_in_read, _p1_in_write = IO.pipe
      p1_out_read, p1_out_write = IO.pipe
      p2_in_read, _p2_in_write = IO.pipe
      p2_out_read, p2_out_write = IO.pipe

      Timeout.timeout(2) do
        fork do
          mutex.with_read_lock do
            p1_out_write.puts 'process 1 written'
            p1_out_write.close

            # wait inside the lock
            puts p1_in_read.read
          end
        end
        fork do
          mutex.with_read_lock do
            p2_out_write.puts 'process 2 written'
            p2_out_write.close

            # wait inside the lock
            puts p2_in_read.read
          end
        end
        # close the blocking reads
        p1_in_read.close
        p2_in_read.close

        # now check that each fork performed the operations at the same time
        expect(p1_out_read.gets).to eq("process 1 written\n")
        expect(p2_out_read.gets).to eq("process 2 written\n")
      end

      # tidy up
      p1_out_read.close
      p2_out_read.close
    end
  end

  describe '#with_write_lock' do
    it 'successfully creates a file lock' do
      foo = mutex.with_write_lock do
        lock_content
      end

      expect(File).to exist(lock_file)
      expect(foo).to eq(lock_content)
    end

    context 'when an exclusive (write) lock is held' do
      it 'will block the shared (read) lock access' do
        p1_in_read, _p1_in_write = IO.pipe
        p1_out_read, p1_out_write = IO.pipe
        p2_in_read, _p2_in_write = IO.pipe
        p2_out_read, p2_out_write = IO.pipe

        # this should perform its operation
        fork do
          mutex.with_write_lock do
            p1_out_write.puts 'process 1 written'
            p1_out_write.close

            # wait inside the lock
            puts p1_in_read.read
          end
        end

        expect do
          # this should block
          Timeout.timeout(1) do
            fork do
              mutex.with_write_lock do
                p2_out_write.puts 'process 2 should not write'
                p2_out_write.close

                # wait inside the lock
                puts p2_in_read.read
              end
            end

            # these will force the mutex
            p1_out_read.gets
            p2_out_read.gets
          end
        end.to raise_error Timeout::Error

        # close the blocking reads
        p1_in_read.close
        p2_in_read.close
      end
    end
  end

  context 'when multiple exclusive (write) locks are requested' do
    it 'will properly release the exclusive lock to enable new locks to be acquired' do
      p1_out_read, p1_out_write = IO.pipe
      p2_out_read, p2_out_write = IO.pipe
      p3_out_read, p3_out_write = IO.pipe
      p4_out_read, p4_out_write = IO.pipe

      fork do
        mutex.with_write_lock do
          p3_out_write.puts 'process 3 written'
          p3_out_write.close
        end
      end
      fork do
        mutex.with_write_lock do
          p1_out_write.puts 'process 1 written'
          p1_out_write.close
        end
      end
      fork do
        mutex.with_write_lock do
          p4_out_write.puts 'process 4 written'
          p4_out_write.close
        end
      end
      fork do
        mutex.with_write_lock do
          p2_out_write.puts 'process 2 written'
          p2_out_write.close
        end
      end

      # now check that each fork performed the operations at the same time
      expect(p1_out_read.gets).to eq("process 1 written\n")
      expect(p2_out_read.gets).to eq("process 2 written\n")
      expect(p3_out_read.gets).to eq("process 3 written\n")
      expect(p4_out_read.gets).to eq("process 4 written\n")
    end
  end
end

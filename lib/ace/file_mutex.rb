# frozen_string_literal: true

require 'timeout'

module ACE
  class FileMutex
    def initialize(lock_file)
      @lock_file = lock_file
    end

    def with_read_lock
      fh = File.open(@lock_file, File::CREAT)
      fh.flock(File::LOCK_SH)
      yield
    ensure
      fh.flock(File::LOCK_UN)
      fh.close
    end

    def with_write_lock
      fh = File.open(@lock_file, File::CREAT)
      fh.flock(File::LOCK_EX)
      yield
    ensure
      fh.flock(File::LOCK_UN)
      fh.close
    end
  end
end

# frozen_string_literal: true

# English module required for $CHILD_STATUS rather than $?
require 'English'

module ACE
  class ForkUtil
    # Forks and calls a function
    # It is expected that the function returns a JSON response
    # Throws an exception if JSON.generate fails to generate
    def self.isolate
      reader, writer = IO.pipe
      pid = fork {
        success = true
        begin
          response = yield
          writer.puts JSON.generate(response)
        rescue StandardError => e
          writer.puts(e)
          success = false
        ensure
          Process.exit! success
        end
      }
      unless pid
        log "Could not fork"
        exit 1
      end
      writer.close
      output = reader.read
      Process.wait(pid)
      if $CHILD_STATUS != 0
        raise output
      else
        JSON.parse(output)
      end
    end
  end
end

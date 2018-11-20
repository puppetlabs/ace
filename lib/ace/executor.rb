# frozen_string_literal: true

module ACE
  class Executor
    def initialize(environment)
      @environment = environment
    end

    def run_task(_targets, _task, _arguments, _options = {})
      {
        status: 'success',
        result: {
          _output: "executed #{taskname} from #{@environment}"
        }
      }
    end
  end
end

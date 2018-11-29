# frozen_string_literal: true

module ACE
  class Executor
    def initialize(environment)
      @environment = environment
    end

    def run_task(_targets, task, arguments, _options = {})
      {
        status: 'success',
        result: {
          output: "executed #{task.name}, with message `#{arguments['message']}` from #{@environment}"
        }
      }
    end
  end
end

# frozen_string_literal: true

module ACE
  class Executor
    def initialize(environment)
      @environment = environment
    end

    def run_task(taskname)
      {
        message: "executed #{taskname} from #{@environment}",
        status: :success
      }
    end
  end
end

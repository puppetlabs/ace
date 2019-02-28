# frozen_string_literal: true

module ACE
  class Executor
    def initialize(environment)
      @environment = environment
    end

    def run_task(connection_info, task, arguments, _options = {})
      if connection_info[:'remote-transport'] == 'panos' &&
         task.files.first['filename'] == 'echo.sh'
        [200, {
          node: 'some_node_id',
          status: 'success',
          result: {
            output: "executed #{task.name}, with message `#{arguments['message']}` from #{@environment}"
          }
        }]
      elsif connection_info[:'remote-transport'] != 'panos'
        [200, {
          node: 'some_node_id',
          status: 'failure',
          result: {
            output: "Invalid Credentials supplied"
          }
        }]
      elsif task['files'].first['filename'] != 'echo.sh'
        [200, {
          node: 'some_node_id',
          status: 'failure',
          result: {
            output: "Unable to execute task: << extended error message here >>"
          }
        }]
      end
    end
  end
end

# frozen_string_literal: true

module ACE
  class Executor
    def initialize(environment)
      @environment = environment
    end

    # This global env is for demo purposes, hence rubocop disables
    # ie. when we don't fork, it persists with our get_demo_env method
    # when we fork, it does not persist
    $demo_env # rubocop:disable Lint/Void, Style/GlobalVars

    def get_demo_env(arguments)
      $demo_env ||= arguments['demo_env'] # rubocop:disable Style/GlobalVars
    end

    def build_response(env)
      [200, {
        node: 'some_node_id',
        status: 'success',
        result: {
          output: "Running from demo environment #{env}"
        }
      }]
    end

    def demo_fork(arguments, _options = {})
      if arguments['fork'] && arguments['fork'].casecmp('true').zero?
        reader, writer = IO.pipe
        require 'puppet'
        pid = fork {
          reader.close
          env = get_demo_env(arguments)
          response = build_response(env)
          writer.puts JSON.generate(response)
        }
        unless pid
          log "Could not fork"
          exit 1
        end
        writer.close
        output = reader.read
        JSON.parse(output)
      else
        env = get_demo_env(arguments)
        build_response(env)
      end
    end

    def run_task(connection_info, task, arguments, _options = {})
      if connection_info[:'remote-transport'] == 'panos' &&
         task.files.first['filename'] == 'echo.sh'
        if arguments['sleep']
          sleep(arguments['sleep'].to_i)
        end
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

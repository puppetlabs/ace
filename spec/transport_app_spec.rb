# frozen_string_literal: true

require 'ace/transport_app'
require 'bolt/target'
require 'bolt/task'
require 'rack/test'

RSpec.describe ACE::TransportApp do
  include Rack::Test::Methods

  def app
    ACE::TransportApp.new
  end

  let(:executor) { instance_double(ACE::Executor, 'executor') }
  before(:each) do
    allow(ACE::Executor).to receive(:new).with('production').and_return(executor)
  end

  it 'responds ok' do
    get '/'
    expect(last_response).to be_ok
    expect(last_response.status).to eq(200)
  end

  let(:target) {
    {
      'host': 'hostname',
      'user': 'user',
      'password': 'password',
      'port': 22,
      'host-key-check': 'false'
    }
  }
  let(:echo_task) {
    {
      'name': 'sample::echo',
      'metadata': {
        'description': 'Echo a message',
        'parameters': { 'message': 'Default message' }
      },
      files: [{
        filename: "echo.sh",
        sha256: "foo",
        uri: {}
      }]
    }
  }

  let(:body) {
    {
      'task': echo_task,
      'target': {
        'hostname': target[:host],
        'user': target[:user],
        'password': target[:password],
        'port': target[:port],
        'host-key-check': false
      },
      'parameters': { "message": "Hello!" }
    }
  }

  it 'runs an echo task' do
    expect(executor).to receive(:run_task)
      .with([instance_of(Bolt::Target)],
            instance_of(Bolt::Task),
            "message" => "Hello!") do |target, task, _params|
              expect(target.size).to eq 1
              expect(target.first).to have_attributes(host: 'hostname')
              expect(task).to have_attributes(name: 'sample::echo')
              { "status" => "success", "result" => { "_output" => 'got passed the message: Hello!' } }
            end

    post '/run_task', JSON.generate(body), 'CONTENT_TYPE' => 'text/json'

    # expect string to be empty and show the string if it's not, since rack/test
    expect(last_response.errors).to match(/\A\Z/)
    expect(last_response).to be_ok
    expect(last_response.status).to eq(200)
    result = JSON.parse(last_response.body)
    expect(result).to include('status' => 'success')
    expect(result['result']['_output']).to match(/got passed the message: Hello!/)
  end
end

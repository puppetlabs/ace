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

  let(:connection_info) {
    {
      'remote-transport': 'panos',
      'address': 'hostname',
      'username': 'user',
      'password': 'password'
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

  let(:execute_catalog_body) {
    {
      "target": {
        "remote-transport": "panos",
        "host": "fw.example.net",
        "user": "foo",
        "password": "wibble"
      },
      "compiler": {
        "certname": certname,
        "environment": "development",
        "transaction_uuid": "<uuid string>",
        "job_id": "<id string>"
      }
    }
  }

  let(:body) {
    {
      'task': echo_task,
      'target': connection_info,
      'parameters': { "message": "Hello!" }
    }
  }

  ################
  # Tasks Endpoint
  ################
  describe '/run_task' do
    it 'runs an echo task' do
      expect(executor).to receive(:run_task)
        .with(connection_info,
              instance_of(Bolt::Task),
              "message" => "Hello!") do |target, task, _params|
        expect(target).to be_a Hash
        expect(task).to have_attributes(name: 'sample::echo')
        [200, { "status" => "success", "result" => { "output" => 'got passed the message: Hello!' } }]
      end

      post '/run_task', JSON.generate(body), 'CONTENT_TYPE' => 'text/json'

      expect(last_response.errors).to match(/\A\Z/)
      expect(last_response).to be_ok
      expect(last_response.status).to eq(200)
      result = JSON.parse(last_response.body)
      expect(result).to include('status' => 'success')
      expect(result['result']['output']).to match(/got passed the message: Hello!/)
    end

    it 'throws an ace/schema_error if the request is invalid' do
      post '/run_task', JSON.generate({}), 'CONTENT_TYPE' => 'text/json'

      expect(last_response.body).to match(%r{ace\/schema-error})
      expect(last_response.status).to eq(400)
    end
  end

  describe '/check' do
    it 'calls the correct method' do
      post '/check', {}, 'CONTENT_TYPE' => 'text/json'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('OK')
    end
  end

  ##################
  # Catalog Endpoint
  ##################
  describe '/execute_catalog' do
    describe 'success' do
      let(:certname) { 'fw.example.net' }
      it 'returns 200 with empty body when success' do
        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to eq({})
      end
    end

    describe 'catalog compile failed' do
      let(:certname) { 'fail.example.net' }
      it 'returns 200 with error in body' do
        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('_error')
        expect(result['_error']['msg']).to eq('catalog compile failed')
      end
    end

    describe 'target specification invalid' do
      let(:certname) { 'credentials.example.net' }
      it 'returns 200 with error in body' do
        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('_error')
        expect(result['_error']['msg']).to eq('target specification invalid')
      end
    end

    describe 'report submission failed' do
      let(:certname) { 'reports.example.net' }
      it 'returns 200 with error in body' do
        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('_error')
        expect(result['_error']['msg']).to eq('report submission failed')
      end
    end
  end
end

require 'spec_helper'

describe ZipkinTracer::Sidekiq::Middleware do

  describe 'call' do
    subject { described_class.new(config) }
    let(:job) { "test_job" }
    let(:queue) { "test_queue" }

    context 'with traceable_workers config option' do
      let(:worker) { "worker" }
      let(:config) do
        {
          service_name: 'test_service',
          traceable_workers: [ :String ]
        }
      end

      it 'traces worker that is specified in config' do
        expect(subject).to receive(:trace)

        subject.call(worker, job, queue) { 2 + 2 }
      end

      it 'does not trace worker that is not specified in config' do
        expect(subject).not_to receive(:trace)

        subject.call(5, job, queue) { 2 + 2 }
      end
    end
  end
end
